"""Normalize API-Football team names to the names the Flutter app uses.

The app (src/app/lib/utils/teams.dart) resolves a flag emoji by *exact* team
name. API-Football spells a handful of nations differently, so map those here.
Unknown names pass through unchanged; the app falls back to a neutral flag.
"""

from __future__ import annotations

# API-Football name -> app name (only entries where they differ).
_ALIASES = {
    "United States": "USA",
    "USA": "USA",
    "Korea Republic": "South Korea",
    "South Korea": "South Korea",
    "Côte d'Ivoire": "Ivory Coast",
    "Cote d'Ivoire": "Ivory Coast",
    "Ivory Coast": "Ivory Coast",
    "IR Iran": "Iran",
    "Iran": "Iran",
}


def normalize(name: str | None) -> str:
    if not name:
        return ""
    return _ALIASES.get(name.strip(), name.strip())
