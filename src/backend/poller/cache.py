"""Local JSON cache of the last-known state per fixture.

Each entry is [status, scoreA, scoreB, goalsRecorded]. We only write a score to
Firestore when the (status, scoreA, scoreB) triple actually changes, so the
cache is what lets us avoid redundant writes — and survive a restart without
re-emitting every score. The trailing goalsRecorded flag tracks whether the
scorer list has been fetched yet, so goals can be backfilled for matches whose
score was first recorded (by the daily sync) without them.
"""

from __future__ import annotations

import json
import logging
import os

log = logging.getLogger("poller.cache")


class Cache:
    def __init__(self, path: str) -> None:
        self.path = path
        self._state: dict = {}
        self._load()

    def _load(self) -> None:
        if os.path.exists(self.path):
            try:
                with open(self.path, "r", encoding="utf-8") as f:
                    self._state = json.load(f)
            except (json.JSONDecodeError, OSError) as e:
                log.warning("Could not read cache %s: %s", self.path, e)
                self._state = {}

    def save(self) -> None:
        tmp = f"{self.path}.tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(self._state, f)
        os.replace(tmp, self.path)

    def changed(self, fixture_id, status, score_a, score_b) -> bool:
        prev = self._state.get(str(fixture_id))
        if prev is None:
            return True
        # Compare only the status/score triple; the optional trailing
        # goals-recorded flag must not count as a score change.
        return prev[:3] != [status, score_a, score_b]

    def status_of(self, fixture_id):
        """Last-known status string for a fixture, or None if never seen."""
        prev = self._state.get(str(fixture_id))
        return prev[0] if prev else None

    def goals_recorded(self, fixture_id) -> bool:
        """Whether the scorer list has been fetched and written for a fixture.

        False for entries written before this flag existed (3-element values) and
        for fixtures only ever seeded by the daily sync (which writes scores but
        not scorers) — that's what lets the poller backfill goals later.
        """
        prev = self._state.get(str(fixture_id))
        return bool(prev[3]) if prev and len(prev) > 3 else False

    def set(self, fixture_id, status, score_a, score_b, goals_recorded=None) -> None:
        """Record a fixture's state. When ``goals_recorded`` is omitted the
        existing flag is preserved, so a daily-sync re-seed never clears scorers
        we've already fetched."""
        key = str(fixture_id)
        if goals_recorded is None:
            goals_recorded = self.goals_recorded(key)
        self._state[key] = [status, score_a, score_b, bool(goals_recorded)]
