"""Match Chat results poller.

A single long-running process meant to run on a personal machine. It:

  1. Syncs the full World Cup schedule into Firestore once per day (~1 request).
  2. Sleeps until the next kickoff (zero requests while idle).
  3. Polls the live endpoint while matches are in play, writing a score to
     Firestore only when it actually changes.
  4. Goes back to sleep when every match has finished.

Sized for the paid plan (7000 requests/day): it polls briskly while matches
are live, and is defensive about the daily quota — a budget guard widens the
interval as the quota runs low, requests stop entirely once it is exhausted,
and every unexpected error backs off before retrying so a failure (or a
crash-restart loop) can never hammer the API.

Run:  python poller.py
"""

from __future__ import annotations

import argparse
import logging
import time
from datetime import datetime, timedelta, timezone

from api_football import ApiFootball, RequestBudget
from cache import Cache
from config import Config
from firestore_sync import FirestoreSync
from mapping import build_group_map, fixture_id, map_status, to_goals, to_match_doc

# How long after kickoff a match might still be in play (90' + half-time +
# stoppage + extra time + penalties, with margin). Defines the polling window.
LIVE_WINDOW = timedelta(hours=3)
# Outer-loop wake cap: re-evaluate (and roll the day / re-sync) at least hourly.
MAX_IDLE_SLEEP = 3600
# How far back to chase down matches that never got a final result. Matches
# older than this are auto-hidden in the app anyway, so there's no point
# re-fetching them every idle cycle.
RECONCILE_LOOKBACK = timedelta(days=2)

log = logging.getLogger("poller")


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _kickoff(fixture: dict):
    raw = fixture.get("fixture", {}).get("date")
    return datetime.fromisoformat(raw) if raw else None


def _in_any_window(schedule: list, now: datetime, prekick: int) -> bool:
    """True if any match is within [kickoff - prekick, kickoff + LIVE_WINDOW]."""
    lead = timedelta(seconds=prekick)
    for fx in schedule:
        ko = _kickoff(fx)
        if ko and (ko - lead) <= now <= (ko + LIVE_WINDOW):
            return True
    return False


def _seconds_until_next_window(schedule: list, now: datetime, prekick: int) -> int:
    """Seconds to the next window start, capped so we re-check hourly."""
    lead = timedelta(seconds=prekick)
    upcoming = [
        (_kickoff(fx) - lead) for fx in schedule if _kickoff(fx) and _kickoff(fx) - lead > now
    ]
    if not upcoming:
        return MAX_IDLE_SLEEP
    delta = (min(upcoming) - now).total_seconds()
    return max(1, min(int(delta), MAX_IDLE_SLEEP))


def daily_sync(api: ApiFootball, fs: FirestoreSync, cache: Cache) -> tuple:
    """Pull the schedule, upsert all match docs, return (schedule, group_map)."""
    schedule = api.schedule()
    group_map = {}
    try:
        group_map = build_group_map(api.standings())
    except Exception as e:  # standings are optional; degrade to no group letters
        log.warning("standings fetch failed (%s); group labels will be generic", e)

    docs = [to_match_doc(fx, group_map) for fx in schedule]
    written = fs.upsert_matches(docs)
    for doc in docs:
        cache.set(doc["apiFixtureId"], doc["status"], doc["scoreA"], doc["scoreB"])
    cache.save()
    log.info("Daily sync: %d fixtures upserted (budget remaining: %d)", written, api.budget.remaining)
    return schedule, group_map


def _poll_interval(cfg: Config, budget: RequestBudget) -> int:
    """Budget guard: widen the interval as the daily quota runs low."""
    remaining = budget.remaining
    if remaining <= 5:
        return cfg.max_poll_interval
    if remaining < 20:
        return min(cfg.max_poll_interval, cfg.poll_interval * 2)
    return cfg.poll_interval


def _write_live(api: ApiFootball, fs: FirestoreSync, cache: Cache, fixture: dict) -> bool:
    """Write a fixture's score/status if it changed, and (back)fill its scorer
    list when goals are on the board but none have been recorded yet. Returns
    True if anything was written."""
    fx = fixture["fixture"]
    fid = fx["id"]
    short = fx.get("status", {}).get("short")
    new_status = map_status(short)
    score = fixture.get("goals", {})
    score_a, score_b = score.get("home"), score.get("away")

    score_changed = cache.changed(fid, new_status, score_a, score_b)
    has_goals = (score_a or 0) + (score_b or 0) > 0
    # Fetch the scorer list when the score just changed, or when there are goals
    # on the board we've never recorded — e.g. the score was first written by the
    # daily sync, which writes scores but not scorers, so change-detection alone
    # would never trigger the fetch.
    need_goals = has_goals and (score_changed or not cache.goals_recorded(fid))

    if not score_changed and not need_goals:
        return False

    goals_recorded = cache.goals_recorded(fid)
    fetched_goals = None
    # Refreshing the scorers costs one extra request, but only fires at scoring /
    # status-change moments (or once, to backfill), so it stays well within the
    # daily budget.
    if need_goals and not api.budget.exhausted:
        try:
            home_id = (fixture.get("teams") or {}).get("home", {}).get("id")
            fetched = to_goals(api.events(fid), home_id)
            if fetched:  # events can lag the score; retry next poll if empty
                fetched_goals = fetched
                goals_recorded = True
        except Exception as e:  # events are best-effort; never block a score write
            log.warning("events fetch failed for %s (%s)", fid, e)

    # Nothing new to persist if the score is unchanged and scorers still aren't
    # available — avoid a redundant write and log line every poll.
    if not score_changed and fetched_goals is None:
        return False

    doc = {
        "apiFixtureId": fid,
        "status": new_status,
        "scoreA": score_a,
        "scoreB": score_b,
    }
    if fetched_goals is not None:
        doc["goals"] = fetched_goals

    fs.update_score(doc)
    cache.set(fid, new_status, score_a, score_b, goals_recorded=goals_recorded)
    log.info("Updated %s: %s %s-%s", fid, new_status, score_a, score_b)
    return True


def run_live_loop(api: ApiFootball, fs: FirestoreSync, cache: Cache, schedule: list, cfg: Config) -> None:
    """Poll while any match is in its live window. Handles finals promptly by
    reconciling fixtures that drop out of the live set."""
    seen_live: set = set()
    while _in_any_window(schedule, _utcnow(), cfg.prekickoff_wake):
        if api.budget.exhausted:
            log.warning("Daily request budget exhausted; pausing live polling")
            time.sleep(cfg.max_poll_interval)
            continue

        try:
            live = api.live()
            current_ids = set()
            wrote = 0
            for fixture in live:
                current_ids.add(fixture["fixture"]["id"])
                if _write_live(api, fs, cache, fixture):
                    wrote += 1

            # Matches that left the live set just finished — fetch their final
            # score.
            finished = list(seen_live - current_ids)
            if finished:
                for fixture in api.fixtures_by_ids(finished):
                    _write_live(api, fs, cache, fixture)
            seen_live = current_ids

            if wrote or finished:
                cache.save()
        except Exception as e:  # one bad poll shouldn't abandon the window
            log.warning("Live poll failed (%s); retrying after the interval", e)

        time.sleep(_poll_interval(cfg, api.budget))

    # Window closed; reconcile anything still marked live (edge case).
    if seen_live and not api.budget.exhausted:
        try:
            for fixture in api.fixtures_by_ids(list(seen_live)):
                _write_live(api, fs, cache, fixture)
            cache.save()
        except Exception as e:
            log.warning("Final reconcile failed (%s); will retry next window", e)


def _needs_reconcile(schedule: list, cache: Cache, now: datetime) -> list:
    """Fixture ids in the recent lookback that still need a (re)write: either
    their live window elapsed without the cache recording them as finished, or
    there are goals on the board whose scorers we never fetched (e.g. the score
    came from the daily sync, which writes scores but not scorers).

    These are matches the live loop never fully handled — typically because the
    poller wasn't running during their window. Bounded to a recent lookback so we
    don't keep chasing long-past fixtures (which the app auto-hides anyway).
    """
    ids = []
    for fx in schedule:
        ko = _kickoff(fx)
        if not ko:
            continue
        if not (ko + LIVE_WINDOW < now < ko + LIVE_WINDOW + RECONCILE_LOOKBACK):
            continue
        fid = fixture_id(fx)
        unfinished = cache.status_of(fid) != "finished"
        g = fx.get("goals") or {}
        has_goals = (g.get("home") or 0) + (g.get("away") or 0) > 0
        missing_goals = has_goals and not cache.goals_recorded(fid)
        if unfinished or missing_goals:
            ids.append(fid)
    return ids


def reconcile(api: ApiFootball, fs: FirestoreSync, cache: Cache, schedule: list) -> None:
    """Catch up recent fixtures the live loop didn't fully handle: finalize any
    match whose window elapsed while we weren't watching, and backfill scorers
    for matches whose score was recorded without them.

    Runs on every wake-up, so a match that ended (or scored) while the poller was
    down is completed within the hour instead of waiting for the next daily sync.
    Once a fixture is written finished with its scorers it drops out of the set,
    so this settles to zero API calls when everything is up to date.
    """
    ids = _needs_reconcile(schedule, cache, _utcnow())
    if not ids or api.budget.exhausted:
        return

    wrote = 0
    for i in range(0, len(ids), 20):  # /fixtures?ids= accepts up to 20
        if api.budget.exhausted:
            break
        try:
            for fixture in api.fixtures_by_ids(ids[i : i + 20]):
                if _write_live(api, fs, cache, fixture):
                    wrote += 1
        except Exception as e:  # best-effort; the daily sync remains the backstop
            log.warning("Reconcile failed (%s); will retry next wake-up", e)
            break

    if wrote:
        cache.save()
        log.info("Reconciled %d fixture(s) (final status / scorers)", wrote)


def _setup():
    """Build the shared config + service objects used by both run modes."""
    cfg = Config.load()
    budget = RequestBudget(cfg.daily_budget)
    api = ApiFootball(cfg, budget)
    fs = FirestoreSync(cfg)
    cache = Cache(cfg.cache_file)
    fs.ensure_tournament()
    return cfg, budget, api, fs, cache


def run_once() -> None:
    """Do a single daily sync (upsert all fixtures) and exit. Useful for
    verifying the Firestore connection and document shape without starting the
    live loop."""
    cfg, budget, api, fs, cache = _setup()
    log.info("One-shot sync for %s (league=%s season=%s)", cfg.tournament_name, cfg.league_id, cfg.season)
    daily_sync(api, fs, cache)
    log.info("Done. %d API request(s) used; budget remaining: %d", budget.used, budget.remaining)


def run_forever() -> None:
    cfg, budget, api, fs, cache = _setup()

    last_sync_date = None
    schedule: list = []

    log.info("Poller started for %s (league=%s season=%s)", cfg.tournament_name, cfg.league_id, cfg.season)
    while True:
        # Any unexpected failure here backs off instead of crashing. A crash
        # under an auto-restart supervisor would re-run the daily sync on every
        # restart and could burn through the quota — the back-off prevents that.
        try:
            today = _utcnow().date()
            if last_sync_date != today and budget.remaining > 2:
                schedule, _ = daily_sync(api, fs, cache)
                last_sync_date = today

            now = _utcnow()
            # Backfill scorers and finalize any match we missed (e.g. while the
            # poller was down) before deciding what to do next. Settles to zero
            # API calls once everything is caught up.
            reconcile(api, fs, cache, schedule)

            if _in_any_window(schedule, now, cfg.prekickoff_wake):
                run_live_loop(api, fs, cache, schedule, cfg)
            else:
                sleep_s = _seconds_until_next_window(schedule, now, cfg.prekickoff_wake)
                log.info("Idle; sleeping %ds (budget remaining: %d)", sleep_s, budget.remaining)
                time.sleep(sleep_s)
        except KeyboardInterrupt:
            raise
        except Exception as e:
            log.exception("Loop iteration failed (%s); backing off %ds", e, cfg.error_backoff)
            time.sleep(cfg.error_backoff)


def main() -> None:
    parser = argparse.ArgumentParser(description="Match Chat results poller.")
    parser.add_argument(
        "--once",
        action="store_true",
        help="Run a single schedule sync (upsert all fixtures) and exit.",
    )
    args = parser.parse_args()

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(name)s %(levelname)s %(message)s",
    )

    if args.once:
        run_once()
    else:
        run_forever()


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        log.info("Stopped.")
