"""Translate API-Football fixtures into Match Chat's Firestore document shape.

Target shape (see src/app/lib/models/match.dart):
    teamA, teamB        team names (flag resolved app-side)
    description         e.g. "Group Stage · Group B" or "Round of 16"
    status             "upcoming" | "live" | "finished"
    scoreA, scoreB     ints or None
    scheduledAt        datetime (UTC) -> Firestore Timestamp
    venue, city        stadium name and host city (strings or None)
    apiFixtureId       the source fixture id (also used as the doc id)
    goals              list of {team, player, minute, extra, penalty, ownGoal}
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

    venue = fx.get("venue") or {}
    venue_name = (venue.get("name") or "").strip() or None
    venue_city = (venue.get("city") or "").strip() or None

    return {
        "apiFixtureId": fx["id"],
        "teamA": normalize(teams["home"].get("name")),
        "teamB": normalize(teams["away"].get("name")),
        "description": _describe(league.get("round", ""), group_letter),
        "status": map_status(fx.get("status", {}).get("short")),
        "scoreA": goals.get("home"),
        "scoreB": goals.get("away"),
        "scheduledAt": scheduled_at,
        "venue": venue_name,
        "city": venue_city,
    }


# Goal events whose detail should not count as a goal on the board.
_GOAL_DETAILS_SKIP = {"Missed Penalty"}


def to_goals(events: list, home_id) -> list:
    """Translate a fixture's events into the match doc's `goals` array.

    Only "Goal" events are kept, ordered by time. `team` is the side the goal
    counts *for* ('A' = home, 'B' = away); own goals are attributed to the
    opponent. Penalty-shootout entries are dropped so the list matches the
    on-pitch score.
    """
    goals = []
    for e in events or []:
        if (e.get("type") or "").lower() != "goal":
            continue
        detail = e.get("detail") or ""
        if detail in _GOAL_DETAILS_SKIP:
            continue
        if (e.get("comments") or "") == "Penalty Shootout":
            continue
        team_id = (e.get("team") or {}).get("id")
        scored_for_home = team_id == home_id
        own_goal = detail == "Own Goal"
        if own_goal:
            scored_for_home = not scored_for_home
        t = e.get("time") or {}
        goals.append(
            {
                "team": "A" if scored_for_home else "B",
                "player": (e.get("player") or {}).get("name") or "Unknown",
                "minute": t.get("elapsed"),
                "extra": t.get("extra"),
                "penalty": detail == "Penalty",
                "ownGoal": own_goal,
            }
        )
    goals.sort(key=lambda g: (g["minute"] or 0) * 100 + (g["extra"] or 0))
    return goals


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
