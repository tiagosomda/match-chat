"""Authoritative knockout-bracket metadata for supported tournaments.

Fixture providers expose a flat schedule.  Kickoff order is not bracket order,
so deriving feeder relationships by sorting dates produces convincing but wrong
connectors.  This module is the deliberate boundary between provider fixtures
and tournament-specific bracket topology.
"""

from __future__ import annotations

import re
from datetime import datetime
from typing import Optional


def _key(value: Optional[str]) -> str:
    return re.sub(r"[^a-z0-9]", "", (value or "").lower())


def _stage(round_name: Optional[str]) -> Optional[str]:
    value = (round_name or "").lower()
    if "round of 32" in value:
        return "r32"
    if "round of 16" in value:
        return "r16"
    if "quarter" in value:
        return "qf"
    if "semi" in value:
        return "sf"
    if ("third" in value or "3rd" in value) and "place" in value:
        return "third"
    if "final" in value:
        return "final"
    return None


# FIFA World Cup 2026 match order, published by FIFA.  The slot sequence is
# deliberately *not* match-number or kickoff order.  Adjacent slots feed the
# same parent in the following round.
_WORLD_CUP_2026_SLOT_BY_MATCH = {
    # Round of 32 -> M89, M90, M93, M94, M91, M92, M95, M96.
    74: 0,
    77: 1,
    73: 2,
    75: 3,
    83: 4,
    84: 5,
    81: 6,
    82: 7,
    76: 8,
    78: 9,
    79: 10,
    80: 11,
    86: 12,
    88: 13,
    85: 14,
    87: 15,
    # Round of 16 -> M97, M98, M99, M100.
    89: 0,
    90: 1,
    93: 2,
    94: 3,
    91: 4,
    92: 5,
    95: 6,
    96: 7,
    # Remaining main bracket.
    97: 0,
    98: 1,
    99: 2,
    100: 3,
    101: 0,
    102: 1,
    104: 0,
}

_WORLD_CUP_2026_ROUND_INDEX = {
    "r32": 1,
    "r16": 2,
    "qf": 3,
    "sf": 4,
    "final": 5,
}


# API-Football does not expose FIFA's official match number.  Stage + host city
# is stable and unique throughout the knockout schedule, except for the two
# Round-of-32 matches in Dallas; their UTC kickoff dates disambiguate them.
# Aliases match the provider's current city spellings after _key normalization.
_WORLD_CUP_2026_MATCH_BY_STAGE_CITY = {
    ("r32", "inglewood"): 73,
    ("r32", "boston"): 74,
    ("r32", "monterrey"): 75,
    ("r32", "houston"): 76,
    ("r32", "newyork"): 77,
    ("r32", "mexicocity"): 79,
    ("r32", "atlanta"): 80,
    ("r32", "sanfrancisco"): 81,
    ("r32", "seattle"): 82,
    ("r32", "toronto"): 83,
    ("r32", "losangeles"): 84,
    ("r32", "vancouver"): 85,
    ("r32", "miami"): 86,
    ("r32", "kansascity"): 87,
    ("r16", "philadelphia"): 89,
    ("r16", "houston"): 90,
    ("r16", "newyork"): 91,
    ("r16", "mexicocity"): 92,
    ("r16", "dallas"): 93,
    ("r16", "seattle"): 94,
    ("r16", "atlanta"): 95,
    ("r16", "vancouver"): 96,
    ("qf", "boston"): 97,
    ("qf", "losangeles"): 98,
    ("qf", "miami"): 99,
    ("qf", "kansascity"): 100,
    ("sf", "dallas"): 101,
    ("sf", "atlanta"): 102,
    ("third", "miami"): 103,
    ("final", "newyork"): 104,
}

_WORLD_CUP_2026_DALLAS_R32_BY_UTC_DATE = {
    "2026-06-30": 78,
    "2026-07-03": 88,
}


def _utc_date(fixture: dict) -> Optional[str]:
    raw = (fixture.get("fixture") or {}).get("date")
    if not raw:
        return None
    try:
        return datetime.fromisoformat(raw.replace("Z", "+00:00")).date().isoformat()
    except (TypeError, ValueError):
        return None


def world_cup_2026_metadata(fixture: dict) -> dict:
    """Return FIFA match number + explicit bracket position for one fixture.

    Unknown fixtures return an empty mapping.  That is intentional: callers
    must never fall back to dates to invent a bracket edge.
    """

    league = fixture.get("league") or {}
    fx = fixture.get("fixture") or {}
    venue = fx.get("venue") or {}
    stage = _stage(league.get("round"))
    city = _key(venue.get("city"))
    if stage is None or not city:
        return {}

    if stage == "r32" and city == "dallas":
        match_number = _WORLD_CUP_2026_DALLAS_R32_BY_UTC_DATE.get(
            _utc_date(fixture)
        )
    else:
        match_number = _WORLD_CUP_2026_MATCH_BY_STAGE_CITY.get((stage, city))
    if match_number is None:
        return {}

    result = {"matchNumber": match_number}
    round_index = _WORLD_CUP_2026_ROUND_INDEX.get(stage)
    bracket_slot = _WORLD_CUP_2026_SLOT_BY_MATCH.get(match_number)
    if round_index is not None and bracket_slot is not None:
        result["roundIndex"] = round_index
        result["bracketSlot"] = bracket_slot
    return result


def bracket_metadata(tournament_id: str, fixture: dict) -> dict:
    """Resolve topology only for tournaments whose format we explicitly know."""

    if tournament_id == "world-cup-2026":
        return world_cup_2026_metadata(fixture)
    return {}
