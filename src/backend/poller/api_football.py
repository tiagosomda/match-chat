"""Thin API-Football (v3) client.

We only ever need scores, so every call goes through /fixtures. One request to
the status-filtered endpoint returns the live score for *every* simultaneous
match, which keeps daily usage tiny relative to the paid plan's 7000/day.
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Optional

import requests

log = logging.getLogger("poller.api")

# Match statuses considered "in play" by API-Football.
LIVE_STATUS_FILTER = "1H-HT-2H-ET-BT-P-SUSP-INT-LIVE"


class RequestBudget:
    """Tracks requests spent against the daily free-plan quota.

    The quota resets at 00:00 UTC. We also read the live remaining count from
    the API's `x-ratelimit-requests-remaining` response header, which is the
    source of truth across restarts within the same day.
    """

    def __init__(self, daily_budget: int) -> None:
        self.daily_budget = daily_budget
        # Track the day in UTC, matching the quota reset and _roll_day_if_needed.
        self._day = datetime.now(timezone.utc).date().isoformat()
        self._used = 0
        self._remaining_header: Optional[int] = None

    def _roll_day_if_needed(self) -> None:
        today = datetime.now(timezone.utc).date().isoformat()
        if today != self._day:
            self._day = today
            self._used = 0
            self._remaining_header = None

    def record(self, remaining_header: Optional[str]) -> None:
        self._roll_day_if_needed()
        self._used += 1
        if remaining_header is not None:
            try:
                self._remaining_header = int(remaining_header)
            except ValueError:
                pass

    @property
    def used(self) -> int:
        self._roll_day_if_needed()
        return self._used

    @property
    def remaining(self) -> int:
        self._roll_day_if_needed()
        if self._remaining_header is not None:
            return self._remaining_header
        return max(0, self.daily_budget - self._used)

    @property
    def exhausted(self) -> bool:
        return self.remaining <= 0


class ApiFootball:
    def __init__(self, config, budget: RequestBudget) -> None:
        self.cfg = config
        self.budget = budget
        self.session = requests.Session()
        self.session.headers.update({"x-apisports-key": config.api_key})

    def _get(self, path: str, params: dict) -> list:
        url = f"{self.cfg.base_url}/{path}"
        resp = self.session.get(url, params=params, timeout=30)
        self.budget.record(resp.headers.get("x-ratelimit-requests-remaining"))
        resp.raise_for_status()
        body = resp.json()
        errors = body.get("errors")
        # API-Football returns 200 with an `errors` object for quota / param issues.
        if errors:
            raise RuntimeError(f"API-Football error: {errors}")
        return body.get("response", [])

    def schedule(self) -> list:
        """All fixtures for the configured league/season (the full schedule)."""
        return self._get(
            "fixtures", {"league": self.cfg.league_id, "season": self.cfg.season}
        )

    def standings(self) -> list:
        """Group tables — used only to label fixtures with their group letter."""
        return self._get(
            "standings", {"league": self.cfg.league_id, "season": self.cfg.season}
        )

    def live(self) -> list:
        """Currently in-play fixtures for this league/season, scores included."""
        return self._get(
            "fixtures",
            {
                "league": self.cfg.league_id,
                "season": self.cfg.season,
                "status": LIVE_STATUS_FILTER,
            },
        )

    def events(self, fixture_id) -> list:
        """Goal/card/substitution events for a single fixture (one request).

        Used to populate the scorer list when a score changes.
        """
        return self._get("fixtures/events", {"fixture": fixture_id})

    def fixtures_by_ids(self, ids: list) -> list:
        """Fetch specific fixtures by id (up to 20 per call, dash-separated).

        Used to grab the final score of a match that has just dropped out of
        the live set.
        """
        if not ids:
            return []
        joined = "-".join(str(i) for i in ids[:20])
        return self._get("fixtures", {"ids": joined})
