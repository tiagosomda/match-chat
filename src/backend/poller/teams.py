"""Normalize API-Football team names to the names the Flutter app uses.

The app (src/app/lib/utils/teams.dart) resolves a flag emoji by *exact* team
name. API-Football spells a handful of nations differently, so map those here.
Unknown names pass through unchanged; the app falls back to a neutral flag.
"""

from __future__ import annotations

# API-Football name -> app name (only entries where they differ).
# Keep this in sync with the app's alias map in src/app/lib/utils/teams.dart.
_ALIASES = {
    "United States": "USA",
    "USA": "USA",
    "Korea Republic": "South Korea",
    "South Korea": "South Korea",
    "Korea DPR": "North Korea",
    "Côte d'Ivoire": "Ivory Coast",
    "Cote d'Ivoire": "Ivory Coast",
    "Ivory Coast": "Ivory Coast",
    "IR Iran": "Iran",
    "Iran": "Iran",
    "Czechia": "Czech Republic",
    "Türkiye": "Turkey",
    "Turkiye": "Turkey",
    "Cabo Verde": "Cape Verde",
    "Congo DR": "DR Congo",
    "Congo-Kinshasa": "DR Congo",
    "North Macedonia": "North Macedonia",
    "Macedonia": "North Macedonia",
    "Bosnia": "Bosnia and Herzegovina",
    "Bosnia and Herzegovina": "Bosnia and Herzegovina",
    "UAE": "United Arab Emirates",
    "Republic of Ireland": "Republic of Ireland",
    "Ireland": "Republic of Ireland",
    "Curacao": "Curaçao",
}


def normalize(name: str | None) -> str:
    if not name:
        return ""
    return _ALIASES.get(name.strip(), name.strip())
