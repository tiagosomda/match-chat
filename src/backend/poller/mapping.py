"""Translate API-Football fixtures into Match Chat's Firestore document shape.

Target shape (see src/app/lib/models/match.dart):
    teamA, teamB        team names (flag resolved app-side)
    description         e.g. "Group Stage · Group B" or "Round of 16"
    status             "upcoming" | "live" | "finished"
    scoreA, scoreB     ints or None
    scheduledAt        datetime (UTC) -> Firestore Timestamp
    apiFixtureId       the source fixture id (also used as the doc id)
"""

from __future__ import annotations

from datetime import datetime
from typing import Optional

from teams import normalize

_FINISHED = {"FT", "AET", "PEN", "WO", "AWD"}
_LIVE = {"1H", "HT", "2H", "ET", "BT", "P", "SUSP", "INT", "LIVE"}


def map_status(short: Optional[str]) -> str:
    if short in _FINISHED:
        return "finished"
    if short in _LIVE:
        return "live"
    return "upcoming"


def _describe(round_name: str, group_letter: Optional[str]) -> str:
    """Human-readable stage label matching the app's existing convention."""
    if round_name and round_name.lower().startswith("group"):
        return f"Group Stage · Group {group_letter}" if group_letter else "Group Stage"
    return round_name or "Match"


def fixture_id(fixture: dict) -> int:
    return fixture["fixture"]["id"]


def to_match_doc(fixture: dict, group_map: dict) -> dict:
    """Build the fields the poller writes. Excludes commentCount/predictionCount
    so the app's own counters are never clobbered (we always merge-write)."""
    fx = fixture["fixture"]
    teams = fixture["teams"]
    goals = fixture.get("goals", {})
    league = fixture.get("league", {})

    home_id = teams["home"].get("id")
    group_letter = group_map.get(home_id)

    scheduled_at: Optional[datetime] = None
    raw_date = fx.get("date")
    if raw_date:
        # API dates look like "2026-06-11T19:00:00+00:00".
        scheduled_at = datetime.fromisoformat(raw_date)

    return {
        "apiFixtureId": fx["id"],
        "teamA": normalize(teams["home"].get("name")),
        "teamB": normalize(teams["away"].get("name")),
        "description": _describe(league.get("round", ""), group_letter),
        "status": map_status(fx.get("status", {}).get("short")),
        "scoreA": goals.get("home"),
        "scoreB": goals.get("away"),
        "scheduledAt": scheduled_at,
    }


def build_group_map(standings_response: list) -> dict:
    """team_id -> group letter (e.g. 'A') from a /standings response."""
    result: dict = {}
    for entry in standings_response:
        groups = entry.get("league", {}).get("standings", [])
        for table in groups:
            for row in table:
                team_id = row.get("team", {}).get("id")
                group = row.get("group", "")  # e.g. "Group A"
                letter = group.replace("Group", "").strip() or None
                if team_id is not None:
                    result[team_id] = letter
    return result
