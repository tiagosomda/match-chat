# Running the Backend Live

How to run the **results poller** that feeds live World Cup scores into
Firestore. The poller is a small Python process meant to run on a personal
machine (laptop, home server, Raspberry Pi…) for the duration of the tournament.

Code + reference docs live in [`src/backend/poller/`](../src/backend/poller/) —
see its [README](../src/backend/poller/README.md) for the architecture and the
full `.env` reference. This document is the operational runbook: how to start it,
keep it running, and what to do when it breaks.

## Prerequisites (one-time setup)

You need three things in place inside `src/backend/poller/`:

1. **`.env`** with a valid `API_FOOTBALL_KEY`.
2. **`service-account.json`** — a Firebase Admin key for the `tiago-dev-site`
   project (Firebase console → Project settings → Service accounts → *Generate
   new private key*).
3. **A `.venv`** with dependencies installed.

If the venv doesn't exist yet:

```bash
cd src/backend/poller
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
```

> **Use the auto-provisioned Firebase Admin service account**
> (`firebase-adminsdk-...@tiago-dev-site.iam.gserviceaccount.com`), not a custom
> service account you create yourself. The auto-provisioned one already has the
> `roles/datastore.user` IAM role; a custom one does not, and Firestore writes
> will fail with `403 PERMISSION_DENIED`. See [Troubleshooting](#troubleshooting).

> **The API-Football plan must cover the target season.** The free plan only
> exposes seasons 2022–2024, so it **cannot** fetch World Cup 2026. A paid plan
> is required for the live tournament.

## Verify the setup (`--once`)

Before running the long-lived process, do a single dry sync. It pulls the full
schedule, upserts every match document into Firestore, and exits — using only
~2 API requests:

```bash
cd src/backend/poller
.venv/bin/python poller.py --once
```

Expected output:

```
poller INFO One-shot sync for FIFA World Cup 2026 (league=1 season=2026)
poller INFO Daily sync: 76 fixtures upserted (budget remaining: 7498)
poller INFO Done. 2 API request(s) used; budget remaining: 7498
```

The fixture count grows toward ~104 as knockout matchups are decided; re-run
`--once` anytime to pick up newly-scheduled matches.

If this succeeds, your key, service account, and Firestore wiring are all good.

## Run it live

For the tournament, run the long-lived process with **no flag**:

```bash
cd src/backend/poller
.venv/bin/python poller.py
```

What it does on a loop:

1. **Daily sync** — once per day, upserts the full schedule (~1 request).
2. **Sleep** — idles until the next kickoff, using **zero** API requests.
3. **Live polling** — while any match is in play, polls a single status-filtered
   request that returns every simultaneous match's score, writing to Firestore
   **only when a score or status actually changes**.
4. **Finals** — fetches a match's final score promptly when it ends, then sleeps.

It's safe to stop (`Ctrl-C`) and restart — a local `.poller-cache.json`
(gitignored) prevents redundant writes across restarts.

### Keeping it running

The process must stay alive to track live scores. Pick whichever fits your host:

- **Quick / interactive** — leave it in a terminal, or use `tmux` / `screen`:
  ```bash
  tmux new -s poller
  cd src/backend/poller && .venv/bin/python poller.py
  # detach with Ctrl-b then d; reattach with: tmux attach -t poller
  ```
- **Background with logs**:
  ```bash
  cd src/backend/poller
  nohup .venv/bin/python poller.py > poller.log 2>&1 &
  tail -f poller.log
  ```
- **Always-on (macOS)** — a `launchd` agent; **(Linux)** — a `systemd` user
  service. Point it at the venv's Python and set the working directory to
  `src/backend/poller`.

## Configuration

All tuning is via `src/backend/poller/.env`. The defaults target World Cup 2026
and stay well within a paid plan's budget. See the
[poller README](../src/backend/poller/README.md#configuration-env) for the full
table. The ones you're most likely to touch:

| Variable | Default | Notes |
|---|---|---|
| `API_FOOTBALL_KEY` | — | **Required.** Paid plan needed for season 2026. |
| `GOOGLE_APPLICATION_CREDENTIALS` | `./service-account.json` | Firebase Admin key. |
| `SEASON` | `2026` | Must be covered by your API-Football plan. |
| `POLL_INTERVAL_SECONDS` | `300` | Interval while matches are live. |
| `DAILY_REQUEST_BUDGET` | `90` | Soft cap; raise it if you're on a higher plan. |

## Troubleshooting

**`403 PERMISSION_DENIED: Missing or insufficient permissions`** (on a Firestore
write, in `ensure_tournament` / `upsert_matches`)
The credential authenticated but isn't authorized to write Firestore. This is an
IAM issue, **not** Firestore security rules (the Admin SDK bypasses rules).
- Confirm `service-account.json` is the auto-provisioned
  `firebase-adminsdk-...@tiago-dev-site.iam.gserviceaccount.com` key. A custom
  service account lacks the Firestore role by default.
- If you must use a custom SA, grant it `roles/datastore.user` (or Owner) in the
  Google Cloud console, then wait 1–2 minutes for IAM to propagate.

**`API-Football error: {'plan': 'Free plans do not have access to this season,
try from 2022 to 2024.'}`**
Your plan can't reach `SEASON=2026`. Upgrade the API-Football plan, or set
`SEASON` to 2022–2024 for testing (note: writes will land under the
`world-cup-2026` tournament doc unless you also change `TOURNAMENT_ID`).

**`API_FOOTBALL_KEY is not set`**
The `.env` file is missing or the key line is still the placeholder. Copy
`.env.example` to `.env` and fill in the key.

**Python 3.9 EOL / LibreSSL urllib3 warnings**
Harmless. They don't affect the poller. To silence them, rebuild the venv on
Python 3.11+.

## How it fits together

```
API-Football  ──(scores)──▶  poller.py  ──(Admin SDK, bypasses rules)──▶  Firestore
                                                                            │
                                          match-chat/app/tournaments/world-cup-2026/matches/{fixtureId}
                                                                            │
                                                                            ▼
                                                                     Flutter app (read)
```

- Writes are **merge-writes**, so the app's own `commentCount` /
  `predictionCount` counters are never overwritten.
- Everything is scoped under the top-level `match-chat` collection, safe in the
  shared `tiago-dev-site` Firebase database.
- Because the poller owns match data, the app's in-app **Seed sample data**
  button is only needed for local development without the poller running.
