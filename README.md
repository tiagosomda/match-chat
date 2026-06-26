# Match Chat

A spoiler-free World Cup companion, built with Flutter Web and Firebase.

This was an experiment — a minimalist take on having a World Cup match schedule
and scores in one place, and potentially chatting about the games with friends
and family. Scores, comments and predictions stay hidden until you choose to
reveal them, so you can catch up on your own clock.

## Features

- Spoiler-free schedule & live scores — reveal on your own clock
- Score predictions with a skill-weighted leaderboard (Global / Friends / Near you)
- Invite-only chat & threaded comments
- See which friends have already watched a match
- Tap a team for its full schedule & results
- Match venues, and English / Spanish / Portuguese (PT & BR)

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
