# Match Chat

A spoiler-free football forum built with **Flutter Web** and **Firebase**
(Auth + Firestore). Scores, predictions and comments stay hidden until *you*
choose to reveal them — match by match. Targets the 2026 FIFA World Cup but the
data model is generic: matches are grouped under tournaments, and the frontend
loads whichever tournament the user prefers.

See ../docs for the product design and the UI design guide.

## Features

- **Two access tiers** — Viewers browse and reveal; Participants (via a
  single-use **invite code**) can comment, chat and predict.
- **Per-user reveal state** — score / predictions / comments revealed
  independently per match, persisted in Firestore.
- **Match list** with search and status filters (upcoming / live / finished /
  archived).
- **Match detail** — Predictions tab (submit before kickoff, reveal everyone's)
  and Comments tab with threaded replies.
- **Global chat** per tournament; match-tagged messages blurred until you
  reveal that match.
- **Profiles** — display name, favorite-team flag avatar, public prediction
  list, invite-code management.
- **Admin** — create / edit / archive matches, set status & final scores.
- **Theming** — Auto / Light / Dark, persisted locally.

## Architecture

    lib/
      firebase_options.dart   Firebase web config (tiago-dev-site)
      models/                 Firestore document models
      services/               Auth + Firestore data access (firestore_refs.dart)
      state/app_state.dart    Session state (provider / ChangeNotifier)
      theme/                  AppColors palette + ThemeData
      utils/                  Teams, validation, formatting
      widgets/                Shared UI (pitch background, avatar, buttons…)
      screens/                Auth, matches, detail, chat, profile, admin

All app data lives under the top-level Firestore collection **match-chat**
(the database is shared with other projects) using a single `match-chat/app`
document with entity sub-collections. See ../firestore.rules.

## Running locally

    cd src
    flutter pub get
    flutter run -d chrome

On first run, sign in (email/password or Google). To get content, an **admin**
user can tap **Seed sample data** on the empty state (or the Match admin
screen) to create the World Cup 2026 tournament with sample matches.

### Granting yourself admin / participant

New users start as Viewers. To promote a user, set `isAdmin: true` (and/or
`isParticipant: true`) on their document at `match-chat/app/users/{uid}` in the
Firebase console.

## Firestore security rules

Rules live in ../firestore.rules and are **not deployed automatically**. They
are scoped entirely under `/match-chat/**` so they never touch sibling projects
in the shared database. Deploy with:

    firebase deploy --only firestore:rules

## Building for production

    flutter build web --no-tree-shake-icons
    # output in src/build/web (the Firebase Hosting public dir)
