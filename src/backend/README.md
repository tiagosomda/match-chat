# Match Chat Backend (Firestore)

Firebase configuration and Firestore security rules for the Match Chat app.

## Files

- **`firebase.json`** — Firebase hosting and Firestore indexes config
- **`firestore.rules`** — Firestore security rules (scoped to `/match-chat/**`)
- **`firestore.indexes.json`** — Composite indexes (currently empty)
- **`poller/`** — Python results poller that fetches live scores from
  API-Football and writes them to Firestore (runs on a personal machine; see
  `poller/README.md`)

## Deployment

From the root of the repo:

```bash
firebase deploy --only firestore:rules
firebase deploy --only hosting
```

Or just rules:
```bash
cd src/backend
firebase deploy --only firestore:rules
```

## Notes

- All rules are scoped under the top-level `match-chat` collection so they don't affect sibling projects in the shared Firebase database
- Hosting public dir points to `src/app/build/web` (the Flutter web build output)
- Rules are **not auto-deployed** — you must run `firebase deploy` manually after updating them
