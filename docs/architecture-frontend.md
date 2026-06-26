# Frontend Architecture

The frontend is a **Flutter Web** app in [`src/app/`](../src/app/). It talks
directly to Firebase (Auth + Firestore) — there is no custom API server.

## Stack

- **Flutter Web** (Dart)
- **Provider** for state management
- **Firebase**: `firebase_auth` + `cloud_firestore`
- **shared_preferences** for local settings (theme, language)

## Layout (`src/app/lib/`)

```
main.dart            App entry; sets up MaterialApp, theme, localization, RootGate
firebase_options.dart

models/              Plain data classes mapped to/from Firestore docs
                     (match, comment, prediction, chat_message, app_user, …)
services/            One class per Firestore concern (match, comment, prediction,
                     chat, reveal, invite, user, auth, tournament). All reads/writes
                     go through here.
state/app_state.dart Single ChangeNotifier holding the session: signed-in user,
                     active tournament, theme + language, and the shared services.
screens/             One file per screen (auth, matches, match detail, chat,
                     leaderboard, country matches, profile, user profile, …)
widgets/             Reusable UI (avatar, buttons, friends sheet, …)
theme/               Color palette + Material theme (light / dark / auto)
utils/               Formatting, validation, team→flag lookup
l10n/                Hand-rolled localization (en, es, pt-PT, pt-BR)
```

## How it flows

1. `main.dart` wraps the app in an `AppState` provider and renders `RootGate`.
2. `RootGate` watches auth state and shows the landing/auth screen, a loading
   splash, or the signed-in `HomeShell` (Matches / Ranks / Chat / Profile tabs).
3. Screens read live data with Firestore `StreamBuilder`s wired to the
   `services/`. Writes call the same services.
4. `AppState` exposes the current user, role flags (`isAdmin`,
   `isParticipant`, `isGuest`), active tournament, theme, and locale.

## Key behaviors

- **Spoiler-free reveals** — scores, comments, predictions and goal scorers
  are blurred until the viewer taps *Reveal*. Each user's reveal choices are
  stored per match (see the backend doc, `userMatchStates`), so the app is
  read-only-safe to browse.
- **Auth modes** — email/password, Google popup, and **anonymous** ("Browse
  matches" guest, read-only). An invite code promotes a user to *participant*
  (chat / comment / predict). See [invite-system.md](./invite-system.md).
- **Tournaments are generic** — the data is keyed by tournament; World Cup 2026
  is just the first one.
- **Localization** — device locale is auto-detected; a picker in
  *Profile → Language* overrides it (persisted locally).

## Run / build

```bash
cd src/app
flutter run -d chrome        # local dev
flutter build web            # production bundle (build/web)
```
