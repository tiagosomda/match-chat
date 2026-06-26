# Match Chat

A spoiler-free World Cup forum built with Flutter Web and Firebase.

## Structure

```
src/
  app/              Flutter web app (see src/app/README.md for dev/build)
  backend/          Firebase config & Firestore rules (src/backend/README.md)
docs/
  ui-design-guide/  Design assets and mockups
  *.md              Product specs, architecture, data model, etc.
firestore.rules     → moved to src/backend/firestore.rules
firebase.json       → moved to src/backend/firebase.json
```

## Quick Start

**Build & serve locally:**
```bash
cd src/app
flutter build web
flutter run -d chrome
```

**Deploy to Firebase:**
```bash
# Frontend (hosting)
cd src/app
flutter build web
firebase deploy --only hosting

# Firestore rules (from root or src/backend)
firebase deploy --only firestore:rules
```

**Configure:**
1. Enable Email/Password and Google Sign-In in Firebase Console (Authentication)
2. Set `isAdmin: true` on your user doc at `match-chat/app/users/{uid}`
3. Tap **Seed sample data** in the app to create World Cup 2026 tournament

## Notes

- See `docs/` for product design, data model, and feature specs
- `example-projects/` is a symlink to your Firebase/GCP patterns repo
- All Firestore rules are scoped under `/match-chat/**` (safe in shared database)
