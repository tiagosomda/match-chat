# Match Chat

A spoiler-free World Cup companion, built with Flutter Web and Firebase.

This was an experiment — a minimalist take on having a World Cup match schedule
and scores in one place, and potentially chatting about the games with friends
and family. Scores, comments and predictions stay hidden until you choose to
reveal them, so you can catch up on your own clock.

## Layout

```
src/app/        Flutter Web app (frontend)
src/backend/    Firebase config, Firestore rules, and the results poller
docs/           Architecture & concepts (below)
```

## Docs

- [Frontend architecture](docs/architecture-frontend.md)
- [Backend architecture](docs/architecture-backend.md)
- [Invite system & moderation](docs/invite-system.md)

## Quick start

```bash
cd src/app
flutter run -d chrome     # run locally
flutter build web         # production build
```
