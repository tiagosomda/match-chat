"""Configuration loaded from the environment (.env)."""

from __future__ import annotations

import os
from dataclasses import dataclass

from dotenv import load_dotenv

load_dotenv()


def _int(name: str, default: int) -> int:
    raw = os.getenv(name)
    return int(raw) if raw else default


@dataclass(frozen=True)
class Config:
    api_key: str
    service_account: str
    base_url: str
    league_id: int
    season: int
    tournament_id: str
    tournament_name: str
    poll_interval: int
    max_poll_interval: int
    prekickoff_wake: int
    daily_budget: int
    error_backoff: int
    cache_file: str

    @staticmethod
    def load() -> "Config":
        api_key = os.getenv("API_FOOTBALL_KEY", "").strip()
        if not api_key:
            raise SystemExit(
                "API_FOOTBALL_KEY is not set. Copy .env.example to .env and fill it in."
            )
        return Config(
            api_key=api_key,
            service_account=os.getenv(
                "GOOGLE_APPLICATION_CREDENTIALS", "./service-account.json"
            ),
            base_url=os.getenv("BASE_URL", "https://v3.football.api-sports.io"),
            league_id=_int("LEAGUE_ID", 1),
            season=_int("SEASON", 2026),
            tournament_id=os.getenv("TOURNAMENT_ID", "world-cup-2026"),
            tournament_name=os.getenv("TOURNAMENT_NAME", "FIFA World Cup 2026"),
            # Paid plan (7000 requests/day): poll briskly while live. The live
            # endpoint returns *every* in-play match in a single request, so a
            # 30s cadence is ~2 req/min — a tiny fraction of the daily budget.
            poll_interval=_int("POLL_INTERVAL_SECONDS", 30),
            max_poll_interval=_int("MAX_POLL_INTERVAL_SECONDS", 120),
            prekickoff_wake=_int("PREKICKOFF_WAKE_SECONDS", 120),
            daily_budget=_int("DAILY_REQUEST_BUDGET", 7000),
            # Sleep this long after any unexpected error so a persistent failure
            # (or crash-restart loop) can never hammer the API.
            error_backoff=_int("ERROR_BACKOFF_SECONDS", 300),
            cache_file=os.getenv("CACHE_FILE", "./.poller-cache.json"),
        )
