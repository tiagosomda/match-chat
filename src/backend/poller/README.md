# Match Chat — Results Poller

A small Python process that fetches World Cup scores from
[API-Football](https://www.api-football.com) and writes them to Firestore. It is
meant to run on a personal machine (laptop, home server, Raspberry Pi…) for the
duration of the tournament.

It is tuned for the **paid plan (7000 requests/day)** — it polls briskly while
matches are live but stays defensive about the daily quota.

## What it does

1. **Daily sync** — once per day, pulls the full schedule (`/fixtures?league=1&season=2026`)
   and upserts all ~104 match documents into Firestore, keyed by the API fixture
   id. This also auto-populates the tournament, so no manual seeding is needed.
2. **Sleep** — idles until the next kickoff. Zero API requests while idle.
3. **Live polling** — while any match is in play, polls a single status-filtered
   request (every 30s by default) that returns the score of *every* simultaneous
   match, and writes to Firestore **only when a score or status actually
   changes** (diffed against a local cache).
4. **Finals** — when a match drops out of the live set, fetches its final score
   promptly, then goes back to sleep.

### Quota safety

The live endpoint returns every in-play match in **one** request, so even a 30s
cadence is ~2 requests/minute — a sliver of the 7000/day budget. On top of that:

- A **budget guard** reads `x-ratelimit-requests-remaining` from the API and
  widens the poll interval as the quota runs low, then **stops requesting**
  entirely once it is exhausted.
- Every unexpected error (API error, network blip) **backs off** for
  `ERROR_BACKOFF_SECONDS` before retrying instead of crashing — so a persistent
  failure, or a crash-restart loop under a supervisor, can never hammer the API.
- All writes are merge-writes against a local change-detection cache, so
  restarts never re-emit scores.

## Setup

1. **Create an API-Football account** and copy your key from the
   [dashboard](https://dashboard.api-football.com).

2. **Download a Firebase service-account key**: Firebase console → Project
   settings → Service accounts → *Generate new private key*. Save the JSON into
   this folder as `service-account.json` (it is gitignored).

3. **Install dependencies** (a virtualenv is recommended):
   ```bash
   cd src/backend/poller
   python3 -m venv .venv
   source .venv/bin/activate
   pip install -r requirements.txt
   ```

4. **Configure**:
   ```bash
   cp .env.example .env
   # edit .env: set API_FOOTBALL_KEY and GOOGLE_APPLICATION_CREDENTIALS
   ```

5. **Verify the connection (recommended first step)** — do a single schedule
   sync and exit, which upserts all fixtures into Firestore without starting the
   live loop:
   ```bash
   python poller.py --once
   ```

6. **Run for real**:
   ```bash
   python poller.py
   ```

Leave it running. It logs each sync and each score update, and is safe to stop
(Ctrl-C) and restart — the local cache prevents redundant writes.

## Configuration (.env)

| Variable | Default | Notes |
|---|---|---|
| `API_FOOTBALL_KEY` | — | Required. |
| `GOOGLE_APPLICATION_CREDENTIALS` | `./service-account.json` | Firebase Admin key. |
| `LEAGUE_ID` / `SEASON` | `1` / `2026` | World Cup 2026 in API-Football. |
| `TOURNAMENT_ID` | `world-cup-2026` | Firestore tournament doc id (matches the app). |
| `POLL_INTERVAL_SECONDS` | `30` | Interval while matches are live. |
| `MAX_POLL_INTERVAL_SECONDS` | `120` | Upper bound the budget guard widens toward. |
| `PREKICKOFF_WAKE_SECONDS` | `120` | Start polling this long before kickoff. |
| `DAILY_REQUEST_BUDGET` | `7000` | Daily ceiling (paid plan). The guard slows then stops as usage nears it. |
| `ERROR_BACKOFF_SECONDS` | `300` | Sleep after any unexpected error before retrying. |
| `CACHE_FILE` | `./.poller-cache.json` | Local change-detection cache. |

## Notes

- Writes go through the **Firebase Admin SDK**, which bypasses Firestore
  security rules — that's why scores can be written even though the client rules
  forbid it. Keep `service-account.json` private.
- All writes are scoped under `match-chat/app/tournaments/{id}/matches/{fixtureId}`,
  safe in the shared Firebase database.
- Match docs are merge-written, so the app's own `commentCount` /
  `predictionCount` counters are never overwritten.
- Because the poller now owns match data, the app's in-app **Seed sample data**
  button is only needed for local development without the poller running.
