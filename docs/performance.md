# Performance & Loading

## Context

The app sometimes feels slow on first load, especially the leaderboard. Cold starts re-fetch everything over the network and screens block on spinners until the first response lands.

**Phase 1** (complete) enabled Firestore's offline cache in [main.dart](../src/app/lib/main.dart), so repeat visits now load cached data (finished match results, predictions, standings, chat) instantly. On the first cold start of each session, screens still block on the network.

These remaining phases improve the user-visible loading experience and fix genuine performance bottlenecks.

## Phase 2: Leaderboard stale-while-revalidate (complete)

Implemented: `LeaderboardService.watch()` is a stale-while-revalidate stream
that emits the in-memory cache, then the Firestore on-disk cache, then the
authoritative server `standings/current` doc (falling back to a client-side
`compute()` only when no doc exists). `LeaderboardScreen` consumes it via a
`StreamSubscription` instead of a `FutureBuilder`, so the list paints from cache
with no blank network wait. Pull-to-refresh still forces a recompute.

**Symptom:** The leaderboard feels slow *every* time you open it, even on repeat visits within the same session, because it shows a blank `FutureBuilder` spinner until the first network response lands.

**Root cause:** The leaderboard [leaderboard_screen.dart:43](../src/app/lib/screens/leaderboard_screen.dart) uses `FutureBuilder` with `app.leaderboard.load()`, which always waits on the network (or a fallback client-side compute). Unlike Matches/Chat, which use `.snapshots()` streams that the SDK keeps warm, the leaderboard has no persistent live subscription.

**Solution:**

1. In `LeaderboardService`:
   - Keep the precomputed `standings/current` doc as the primary source (it's already in the cache from Phase 1).
   - Change `.load()` to try `Source.cache` first (instant), then refresh from server in background.
   - Fall back to client-side `compute()` only if neither cache nor server doc exists.

2. In `LeaderboardScreen`:
   - Instead of `FutureBuilder` (all-or-nothing), stream the data like Matches does. Or keep `FutureBuilder` but render the header + filters immediately while the list loads.

**Effort:** Low (refactor the service's read order + source hints).

**Impact:** Opens instantly on repeat visits + within-session revisits; no blank spinner.

## Phase 3: Render shell before data

> Applied to the **Leaderboard/Ranks** screen alongside Phase 2: its header,
> tabs, search and legend now render immediately while only the list waits,
> showing a pulsing skeleton (`_SkeletonList`) instead of a full-screen spinner.
> Matches and My Predictions still wait on their top-level builders — pending.

**Symptom:** Every screen (Matches, Leaderboard, My Predictions) shows a full-screen spinner until the first network/cache response lands.

**Root cause:** Each screen's top-level `build()` calls `StreamBuilder` or `FutureBuilder`, blocking the entire widget tree until the snapshot arrives.

**Solution:** Separate the header/chrome from the list:

1. Render `HomeShell` immediately (header + logo + bottom nav).
2. Inside each tab's body, render the header (title, filters, search) outside the `StreamBuilder`.
3. Put only the *list* inside the async builder — it shows a lightweight placeholder (skeleton or empty state) while loading.

Example (Matches tab):

```dart
@override
Widget build(BuildContext context) {
  return Column(
    children: [
      _header(...),     // Always visible
      _filters(...),    // Always visible
      Expanded(
        child: StreamBuilder<List<MatchModel>>(
          stream: _matchesStream,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return _skeletonPlaceholder();  // Lightweight, not full-screen
            }
            return ListView(children: [...snap.data]);
          },
        ),
      ),
    ],
  );
}
```

**Effort:** Medium (restructure each screen's layout; add skeleton placeholders).

**Impact:** User sees familiar UI immediately, knows the screen loaded (just still fetching list). Feels faster.

## Phase 4: Parallelize N+1 queries

**Symptom:** Opening a user's profile is slow; pulling to refresh the leaderboard is very slow.

**Root cause:** Two screens make sequential Firestore reads:

1. **User profile** → [prediction_service.dart:92 `fetchForUserAcross()`](../src/app/lib/services/prediction_service.dart):
   ```dart
   for (final m in matchesSnap.docs) {          // ~78 sequential reads
     final p = await Refs.predictions(tid, m.id).doc(uid).get();
     if (p.exists) result.add(...);
   }
   ```

2. **Leaderboard force-refresh** → [leaderboard_service.dart:62 `compute()`](../src/app/lib/services/leaderboard_service.dart):
   ```dart
   for (final mdoc in matchesSnap.docs) {       // ~100 sequential reads
     if (!match.hasScore) continue;
     final predsSnap = await Refs.predictions(tid, match.id).get();
     for (final pdoc in predsSnap.docs) { ... }  // Then another loop per match
   }
   ```

On a fast connection these are ~1–2s per 10 reads; on a slower connection they're unbearable.

**Solution:** Parallelize with `Future.wait`:

```dart
// Before (sequential):
for (final m in matches) {
  final p = await fetch(m.id);
  result.add(p);
}

// After (parallel):
final futures = matches.map((m) => fetch(m.id));
final results = await Future.wait(futures);
```

Also consider **server-side aggregation** as a longer-term win: have the backend precompute user profiles (total predictions, accuracy) and serve them in a single doc, rather than reconstructing them client-side.

**Effort:** Low (refactor loops to `.map().wait()`) + medium (if implementing server aggregation).

**Impact:** Profile opens ~3–5× faster; leaderboard refresh on large datasets becomes acceptable.

## Testing strategy

Each phase should be tested locally:
1. Clear site data / hard refresh to reset the cache.
2. Load the app and measure time-to-first-contentful-paint (DevTools Network tab).
3. Reload within the same session to verify cache hit.
4. Measure slowest-path (profile open, leaderboard pull-to-refresh) before and after.

On slow 4G (Chrome DevTools > Throttling), the differences are most visible.
