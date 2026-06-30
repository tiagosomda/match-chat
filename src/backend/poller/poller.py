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
import json
import logging
import os
import time
from datetime import datetime, timedelta, timezone
from logging.handlers import TimedRotatingFileHandler

from api_football import ApiFootball, RequestBudget
from cache import Cache
from config import Config
from firestore_sync import FirestoreSync
from mapping import (
    build_group_map,
    fixture_id,
    map_status,
    to_goals,
    to_match_doc,
    to_shootout,
)

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

    docs = [to_match_doc(fx, group_map, fs.cfg.tournament_id) for fx in schedule]
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


def _shootout_signature(shootout: dict) -> str:
    return json.dumps(shootout, sort_keys=True, separators=(",", ":"))


def _shootout_is_complete(shootout: dict) -> bool:
    """Whether a final event list contains the decisive kick.

    API-Football gives us the scored tally but no expected attempt count. The
    ordinary five-round phase is complete once neither side can catch the
    other; sudden death is complete after an equal number of kicks with unequal
    scores. We also verify that every scored kick in the tally has an event.
    """
    if shootout.get("state") != "finished":
        return False
    attempts = shootout.get("attempts") or []
    if not attempts:
        return False
    score_a = shootout.get("scoreA") or 0
    score_b = shootout.get("scoreB") or 0
    scored_a = sum(1 for a in attempts if a.get("team") == "A" and a.get("scored"))
    scored_b = sum(1 for a in attempts if a.get("team") == "B" and a.get("scored"))
    if scored_a != score_a or scored_b != score_b:
        return False
    kicks_a = sum(1 for a in attempts if a.get("team") == "A")
    kicks_b = sum(1 for a in attempts if a.get("team") == "B")
    if kicks_a <= 5 and kicks_b <= 5:
        return (
            score_a > score_b + (5 - kicks_b)
            or score_b > score_a + (5 - kicks_a)
        )
    return kicks_a == kicks_b and score_a != score_b


def _write_live(api: ApiFootball, fs: FirestoreSync, cache: Cache, fixture: dict) -> bool:
    """Write changed score/status, regular goals, and penalty-shootout kicks."""
    fx = fixture["fixture"]
    fid = fx["id"]
    short = fx.get("status", {}).get("short")
    new_status = map_status(short)
    score = fixture.get("goals", {})
    score_a, score_b = score.get("home"), score.get("away")

    score_changed = cache.changed(fid, new_status, score_a, score_b)
    expected_goals = (score_a or 0) + (score_b or 0)
    has_goals = expected_goals > 0
    # Fetch the scorer list when the score just changed, or when there are goals
    # on the board we've never recorded — e.g. the score was first written by the
    # daily sync, which writes scores but not scorers, so change-detection alone
    # would never trigger the fetch.
    need_goals = has_goals and (score_changed or not cache.goals_recorded(fid))
    shootout_summary = to_shootout(fixture)
    has_shootout = shootout_summary is not None
    # A missed kick does not change score.penalty, so while status=P the events
    # endpoint must be checked each poll. Finished shootouts are retried until a
    # complete decisive sequence has been persisted.
    need_shootout = has_shootout and (
        short == "P" or not cache.shootout_recorded(fid)
    )

    goals_recorded = cache.goals_recorded(fid)
    shootout_recorded = cache.shootout_recorded(fid)
    fetched_goals = None
    shootout_doc = None
    shootout_signature = cache.shootout_signature(fid)
    shootout_changed = False
    fetched_events = None
    # Refreshing the scorers costs one extra request, but only fires at scoring /
    # status-change moments (or once, to backfill). During a shootout it also
    # fires once per poll because misses cannot be inferred from the tally.
    if (need_goals or need_shootout) and not api.budget.exhausted:
        try:
            home_id = (fixture.get("teams") or {}).get("home", {}).get("id")
            fetched_events = api.events(fid)
            fetched = to_goals(fetched_events, home_id)
            # The events endpoint can lag by one goal while still returning a
            # non-empty list. Only mark it complete when every goal currently
            # on the scoreboard has a matching event; otherwise leave the flag
            # false so the next poll retries.
            if need_goals:
                if len(fetched) >= expected_goals:
                    fetched_goals = fetched
                    goals_recorded = True
                else:
                    goals_recorded = False
                    log.debug(
                        "Events incomplete for %s: got %d of %d goal(s); will retry",
                        fid, len(fetched), expected_goals,
                    )
        except Exception as e:  # events are best-effort; never block a score write
            log.warning("events fetch failed for %s (%s)", fid, e)

    if has_shootout:
        if fetched_events is not None:
            shootout_doc = to_shootout(fixture, fetched_events)
            candidate = _shootout_signature(shootout_doc)
            shootout_changed = candidate != shootout_signature
            shootout_signature = candidate
            shootout_recorded = _shootout_is_complete(shootout_doc)
        elif shootout_signature is None:
            # Even without event capacity, surface that the match reached
            # penalties. The next successful P/PEN fetch will add attempts.
            shootout_doc = shootout_summary
            shootout_signature = _shootout_signature(shootout_doc)
            shootout_changed = True

    # Nothing new to persist if the score is unchanged and scorers still aren't
    # available and the shootout sequence is unchanged.
    if not score_changed and fetched_goals is None and not shootout_changed:
        return False

    doc = {
        "apiFixtureId": fid,
        "status": new_status,
        "scoreA": score_a,
        "scoreB": score_b,
    }
    if fetched_goals is not None:
        doc["goals"] = fetched_goals
    elif score_changed and expected_goals == 0:
        # A disallowed/corrected goal can move the score back to 0-0. Clear any
        # stale scorer events that were written for the former score.
        doc["goals"] = []
        goals_recorded = True
    if shootout_changed and shootout_doc is not None:
        doc["shootout"] = shootout_doc

    fs.update_score(doc)
    cache.set(
        fid,
        new_status,
        score_a,
        score_b,
        goals_recorded=goals_recorded,
        shootout_signature=shootout_signature,
        shootout_recorded=shootout_recorded,
    )
    pens = ""
    if shootout_doc is not None:
        pens = f" pens={shootout_doc['scoreA']}-{shootout_doc['scoreB']}"
    log.info("Updated %s: %s %s-%s%s", fid, new_status, score_a, score_b, pens)
    return True


def run_live_loop(api: ApiFootball, fs: FirestoreSync, cache: Cache, schedule: list, cfg: Config) -> None:
    """Poll while any match is in its live window. Handles finals promptly by
    reconciling fixtures that drop out of the live set."""
    # Pre-seed with any fixture currently in its window that isn't finished —
    # so a match that ended while we were down still gets reconciled on first poll.
    now = _utcnow()
    lead = timedelta(seconds=cfg.prekickoff_wake)
    seen_live: set = {
        fixture_id(fx)
        for fx in schedule
        if (ko := _kickoff(fx))
        and (ko - lead) <= now <= (ko + LIVE_WINDOW)
        and cache.status_of(fixture_id(fx)) != "finished"
    }
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
                fid = fixture["fixture"]["id"]
                current_ids.add(fid)
                score = fixture.get("goals", {})
                short = fixture.get("fixture", {}).get("status", {}).get("short", "?")
                log.debug(
                    "Poll: fixture %s status=%s score=%s-%s",
                    fid, short, score.get("home"), score.get("away"),
                )
                if _write_live(api, fs, cache, fixture):
                    wrote += 1

            appeared = current_ids - seen_live
            dropped = seen_live - current_ids
            if appeared:
                log.info("Live set +%s: %s", len(appeared), sorted(appeared))
            if dropped:
                log.info("Live set -%s (fetching final): %s", len(dropped), sorted(dropped))

            # Matches that left the live set just finished — fetch their final
            # score.
            if dropped:
                for fixture in api.fixtures_by_ids(list(dropped)):
                    _write_live(api, fs, cache, fixture)
            seen_live = current_ids

            log.debug("Poll summary: %d in play, %d written", len(current_ids), wrote)
            if wrote or dropped:
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

    # A live window just ended, so some matches likely just finished — refresh
    # the cached leaderboard so the app's Ranks tab loads instantly (#8).
    _recompute_standings(fs)


def _recompute_standings(fs: FirestoreSync) -> None:
    """Best-effort leaderboard refresh; never let it disrupt the poll loop."""
    try:
        n = fs.recompute_standings()
        log.info("Recomputed leaderboard standings: %d player(s)", n)
    except Exception as e:
        log.warning("Standings recompute failed (%s)", e)


def _backfill_renames(fs: FirestoreSync) -> bool:
    """Best-effort display-name backfill; never let it disrupt the poll loop.
    Returns True if any renames were processed."""
    try:
        processed = fs.backfill_renames()
        return processed > 0
    except Exception as e:
        log.warning("Rename backfill failed (%s)", e)
        return False


def _needs_reconcile(schedule: list, cache: Cache, now: datetime) -> list:
    """Fixture ids in the recent lookback that still need a (re)write: either
    their live window elapsed without the cache recording them as finished, or
    there are goals on the board whose scorers we never fetched (e.g. the score
    came from the daily sync, which writes scores but not scorers), or a final
    penalty shootout whose complete kick sequence has not been recorded.

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
        short = ((fx.get("fixture") or {}).get("status") or {}).get("short")
        missing_shootout = (
            short == "PEN" or cache.shootout_signature(fid) is not None
        ) and not cache.shootout_recorded(fid)
        if unfinished or missing_goals or missing_shootout:
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
        # Finals may have been written — refresh the cached leaderboard (#8).
        _recompute_standings(fs)


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
    _recompute_standings(fs)
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

            # Trickle display-name changes onto a few users' old messages (#14).
            # Firestore-only work, no API quota cost. If names changed, recompute
            # standings since prediction displayNames may have been updated.
            if _backfill_renames(fs):
                _recompute_standings(fs)

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

    fmt = logging.Formatter("%(asctime)s %(name)s %(levelname)s %(message)s")

    console = logging.StreamHandler()
    console.setLevel(logging.INFO)
    console.setFormatter(fmt)

    os.makedirs("logs", exist_ok=True)
    file_handler = TimedRotatingFileHandler(
        "logs/poller.log", when="midnight", backupCount=30, utc=True
    )
    file_handler.setLevel(logging.DEBUG)
    file_handler.setFormatter(fmt)

    root = logging.getLogger()
    root.setLevel(logging.DEBUG)
    root.addHandler(console)
    root.addHandler(file_handler)

    if args.once:
        run_once()
    else:
        run_forever()


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        log.info("Stopped.")
