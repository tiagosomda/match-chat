import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/leaderboard_entry.dart';
import '../models/match.dart';
import '../models/prediction.dart';
import '../utils/scoring.dart';
import 'firestore_refs.dart';

/// Computes the prediction leaderboard for a tournament (improvements.md #8).
///
/// There is no server-side aggregation, so the standing is built client-side:
/// for every finished match with a known score, each user's prediction is
/// scored (5 / 3 / 1 points) and summed per user. This is a read-heavy but
/// occasional operation, so it is a one-shot fetch rather than a live stream.
class LeaderboardService {
  // A short-lived in-memory cache so flipping to the Ranks tab and back is
  // instant rather than recomputing every time (#8).
  final Map<String, List<LeaderboardEntry>> _mem = {};
  final Map<String, DateTime> _memAt = {};
  static const Duration _memTtl = Duration(seconds: 45);

  /// Loads the standing for the Ranks tab. Order of preference (#8):
  ///   1. the in-memory cache, if still fresh (instant tab switches),
  ///   2. the poller-maintained `standings/current` doc (one quick read),
  ///   3. a client-side [compute] fallback (when the poller hasn't run).
  ///
  /// [force] (pull-to-refresh) skips both caches and recomputes from Firestore
  /// so a just-finished match is reflected even if the poller is briefly behind.
  Future<List<LeaderboardEntry>> load(String tid, {bool force = false}) async {
    if (!force) {
      final at = _memAt[tid];
      final cached = _mem[tid];
      if (at != null &&
          cached != null &&
          DateTime.now().difference(at) < _memTtl) {
        return cached;
      }
      try {
        final entries = _entriesFromDoc(await Refs.standings(tid).get());
        if (entries != null) return _remember(tid, entries);
      } catch (_) {
        // Fall through to a client-side compute.
      }
    }
    return _remember(tid, await compute(tid));
  }

  /// Stale-while-revalidate stream for the Ranks tab (performance.md Phase 2).
  ///
  /// Emits whatever is available *immediately* — the in-memory cache, then the
  /// Firestore on-disk cache — so the list paints without a network wait, then
  /// emits the authoritative server standing (or a client-side compute when no
  /// `standings/current` doc exists) once it arrives. Repeat visits within a
  /// session are instant; cross-session visits paint from the disk cache first.
  Stream<List<LeaderboardEntry>> watch(String tid) async* {
    // 1. In-memory cache — instant tab flips within the session.
    final at = _memAt[tid];
    final cached = _mem[tid];
    if (at != null &&
        cached != null &&
        DateTime.now().difference(at) < _memTtl) {
      yield cached;
      return;
    }

    var emitted = false;

    // 2. Firestore's on-disk cache — instant on repeat visits across sessions.
    try {
      final entries = _entriesFromDoc(
        await Refs.standings(tid).get(const GetOptions(source: Source.cache)),
      );
      if (entries != null) {
        emitted = true;
        yield _remember(tid, entries);
      }
    } catch (_) {
      // No cached doc yet — fall through to the network.
    }

    // 3. Authoritative server read.
    try {
      final entries = _entriesFromDoc(
        await Refs.standings(tid).get(const GetOptions(source: Source.server)),
      );
      if (entries != null) {
        yield _remember(tid, entries);
        return;
      }
    } catch (_) {
      // Offline or the doc is missing — fall through to compute.
    }

    // 4. Last resort: compute client-side. Skip if we already painted a cached
    //    standing (a stale-but-valid cache beats a slow recompute).
    if (!emitted) {
      yield _remember(tid, await compute(tid));
    }
  }

  /// Parses the `entries` array of a `standings/current` doc, or null when the
  /// doc is missing or empty.
  List<LeaderboardEntry>? _entriesFromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final raw = doc.data()?['entries'] as List?;
    if (raw == null || raw.isEmpty) return null;
    return raw
        .map((e) => LeaderboardEntry.fromMap((e as Map).cast<String, dynamic>()))
        .toList();
  }

  List<LeaderboardEntry> _remember(String tid, List<LeaderboardEntry> entries) {
    _mem[tid] = entries;
    _memAt[tid] = DateTime.now();
    return entries;
  }

  /// Builds the full standing, sorted best-first with dense-by-points ranks.
  Future<List<LeaderboardEntry>> compute(String tid) async {
    // Only finished matches contribute; the equality filter keeps reads down.
    final matchesSnap = await Refs.matches(tid)
        .where('status', isEqualTo: MatchStatus.finished.id)
        .get();

    final accumulators = <String, _Acc>{};
    for (final mdoc in matchesSnap.docs) {
      final match = MatchModel.fromDoc(mdoc);
      if (!match.hasScore) continue;
      final predsSnap = await Refs.predictions(tid, match.id).get();
      for (final pdoc in predsSnap.docs) {
        final pred = Prediction.fromDoc(pdoc);
        final pts = Scoring.points(
          pred.scoreA,
          pred.scoreB,
          match.scoreA!,
          match.scoreB!,
        );
        final acc = accumulators.putIfAbsent(
          pred.userId,
          () => _Acc(pred.userId),
        );
        acc.points += pts;
        acc.scored += 1;
        if (pts == Scoring.exactPoints) acc.exact += 1;
        // Keep the most recent name/flag we encounter for the user.
        acc.displayName = pred.displayName;
        if (pred.favoriteTeam != null) acc.favoriteTeam = pred.favoriteTeam;
      }
    }

    final entries =
        accumulators.values
            .map(
              (a) => LeaderboardEntry(
                userId: a.userId,
                displayName: a.displayName,
                points: a.points,
                exact: a.exact,
                scored: a.scored,
                favoriteTeam: a.favoriteTeam,
              ),
            )
            .toList()
          ..sort(_compare);

    // Dense competition ranking: equal points share a rank.
    int rank = 0;
    int? prevPoints;
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      if (prevPoints == null || e.points != prevPoints) {
        rank = i + 1;
        prevPoints = e.points;
      }
      e.rank = rank;
    }
    return entries;
  }

  static int _compare(LeaderboardEntry a, LeaderboardEntry b) {
    if (b.points != a.points) return b.points.compareTo(a.points);
    if (b.exact != a.exact) return b.exact.compareTo(a.exact);
    return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
  }
}

class _Acc {
  _Acc(this.userId);
  final String userId;
  String displayName = '';
  String? favoriteTeam;
  int points = 0;
  int exact = 0;
  int scored = 0;
}
