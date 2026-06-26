"""Local JSON cache of the last-known state per fixture.

We only write to Firestore when a fixture's (status, scoreA, scoreB) actually
changes, so the cache is what lets us avoid redundant writes — and survive a
restart without re-emitting every score.
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
        return prev != [status, score_a, score_b]

    def status_of(self, fixture_id):
        """Last-known status string for a fixture, or None if never seen."""
        prev = self._state.get(str(fixture_id))
        return prev[0] if prev else None

    def set(self, fixture_id, status, score_a, score_b) -> None:
        self._state[str(fixture_id)] = [status, score_a, score_b]
