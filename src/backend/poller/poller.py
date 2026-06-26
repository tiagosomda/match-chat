"""Match Chat results poller.

A single long-running process meant to run on a personal machine. It:

  1. Syncs the full World Cup schedule into Firestore once per day (~1 request).
  2. Sleeps until the next kickoff (zero requests while idle).
  3. Polls the live endpoint while matches are in play, writing a score to
     Firestore only when it actually changes.
  4. Goes back to sleep when every match has finished.

Designed to stay inside API-Football's free plan (100 requests/day).

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
from mapping import build_group_map, map_status, to_goals, to_match_doc

# How long after kickoff a match might still be in play (90' + half-time +
# stoppage + extra time + penalties, with margin). Defines the polling window.
LIVE_WINDOW = timedelta(hours=3)
# Outer-loop wake cap: re-evaluate (and roll the day / re-sync) at least hourly.
MAX_IDLE_SLEEP = 3600

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
    """Write a fixture's score/status if it changed. Returns True if written."""
    fx = fixture["fixture"]
    fid = fx["id"]
    short = fx.get("status", {}).get("short")
    new_status = map_status(short)
    score = fixture.get("goals", {})
    score_a, score_b = score.get("home"), score.get("away")

    if not cache.changed(fid, new_status, score_a, score_b):
        return False

    doc = {
        "apiFixtureId": fid,
        "status": new_status,
        "scoreA": score_a,
        "scoreB": score_b,
    }

    # Refresh the scorer list whenever there are goals on the board. This costs
    # one extra request, but only fires at scoring/status-change moments, so it
    # stays well within the daily budget.
    if (score_a or 0) + (score_b or 0) > 0 and not api.budget.exhausted:
        try:
            home_id = (fixture.get("teams") or {}).get("home", {}).get("id")
            doc["goals"] = to_goals(api.events(fid), home_id)
        except Exception as e:  # events are best-effort; never block a score write
            log.warning("events fetch failed for %s (%s)", fid, e)

    fs.update_score(doc)
    cache.set(fid, new_status, score_a, score_b)
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

        live = api.live()
        current_ids = set()
        wrote = 0
        for fixture in live:
            current_ids.add(fixture["fixture"]["id"])
            if _write_live(api, fs, cache, fixture):
                wrote += 1

        # Matches that left the live set just finished — fetch their final score.
        finished = list(seen_live - current_ids)
        if finished:
            for fixture in api.fixtures_by_ids(finished):
                _write_live(api, fs, cache, fixture)
        seen_live = current_ids

        if wrote or finished:
            cache.save()

        time.sleep(_poll_interval(cfg, api.budget))

    # Window closed; reconcile anything still marked live (edge case).
    if seen_live and not api.budget.exhausted:
        for fixture in api.fixtures_by_ids(list(seen_live)):
            _write_live(api, fs, cache, fixture)
        cache.save()


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
        today = _utcnow().date()
        if last_sync_date != today and budget.remaining > 2:
            schedule, _ = daily_sync(api, fs, cache)
            last_sync_date = today

        now = _utcnow()
        if _in_any_window(schedule, now, cfg.prekickoff_wake):
            run_live_loop(api, fs, cache, schedule, cfg)
        else:
            sleep_s = _seconds_until_next_window(schedule, now, cfg.prekickoff_wake)
            log.info("Idle; sleeping %ds (budget remaining: %d)", sleep_s, budget.remaining)
            time.sleep(sleep_s)


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
