# Backend Architecture

There is no custom server. The "backend" is **Firebase** plus a small **Python
poller** that feeds in live scores. Config lives in
[`src/backend/`](../src/backend/).

## Pieces

- **Firebase Auth** — email/password, Google, and anonymous (guest) sign-in.
- **Cloud Firestore** — all app data.
- **Security rules** — [`src/backend/firestore.rules`](../src/backend/firestore.rules),
  enforce roles and ownership on the client.
- **Results poller** — [`src/backend/poller/`](../src/backend/poller/), a Python
  process that writes live match scores and goal scorers using the Firebase
  Admin SDK.

## Shared database, one namespace

The Firestore database is **shared with other projects**, so everything is
scoped under a single top-level collection, `match-chat`, hung off one app
document. A single rule on `/match-chat/{document=**}` covers the whole app and
never touches sibling projects.

```
match-chat/app
  ├── users/{uid}                       displayName, roles, favoriteTeam,
  │                                      friends[], invitedBy, preferredLanguage
  ├── tournaments/{tid}
  │     ├── matches/{mid}               teams, status, score, scheduledAt,
  │     │     │                         venue/city, goals[], cached counts
  │     │     ├── comments/{cid}        threaded; soft-deletable
  │     │     └── predictions/{uid}     one per user per match
  │     └── chat/{msgId}                tournament-wide chat, optionally match-tagged
  ├── inviteCodes/{code}                createdBy, usedBy (the invite tree)
  └── userMatchStates/{uid}_{mid}       per-user reveal flags (score/comments/…)
```

## Roles and rules

Two flags on the user doc drive everything:

- **`isParticipant`** — can post comments, chat and predictions. Granted by
  redeeming an invite code (see [invite-system.md](./invite-system.md)).
- **`isAdmin`** — can create/edit/archive matches and delete any comment.

The rules enforce, among other things: a user may only write their own
profile/reveals/predictions; nobody can grant themselves admin; comment edits
and deletes are limited to the author or an admin; and reveal state is
world-readable (it holds only booleans, never the score) so the friends feature
can show who has already watched.

## Live scores: the poller

`poller.py` runs on a personal machine for the duration of a tournament:

1. **Daily sync** — pulls the full schedule from API-Football and upserts every
   match document (~1 request/day).
2. **Sleep** — idles until the next kickoff (zero requests).
3. **Live polling** — while matches are in play, polls one status-filtered
   request that returns every simultaneous score, writing to Firestore **only
   when a score/status changes**. On a goal it also fetches the scorer events.
4. **Finals** — writes the final score promptly, then sleeps.

The Admin SDK **bypasses security rules**, and all writes are **merge-writes**,
so the app's own counters (`commentCount`, `predictionCount`) and `archived`
flag are never clobbered. A local cache prevents redundant writes across
restarts. See the [poller README](../src/backend/poller/README.md) for setup and
the operational runbook.

```
API-Football ──▶ poller.py ──(Admin SDK)──▶ Firestore ──▶ Flutter app (read)
```

## Deploy

```bash
# Firestore rules
cd src/backend && firebase deploy --only firestore:rules

# Frontend (hosting) — build first
cd src/app && flutter build web && firebase deploy --only hosting
```
