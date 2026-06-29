import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/leaderboard_entry.dart';
import 'firestore_refs.dart';

/// Reads the poller-computed prediction leaderboard for a tournament.
///
/// Ranking is intentionally a backend concern: the poller aggregates predictions
/// into `standings/current`, and clients read that single document. Keeping the
/// expensive fallback off the client prevents one query per finished match.
class LeaderboardService {
  // A short-lived in-memory cache so flipping to the Ranks tab and back is
  // instant rather than recomputing every time (#8).
  final Map<String, List<LeaderboardEntry>> _mem = {};
  final Map<String, DateTime> _memAt = {};
  static const Duration _memTtl = Duration(seconds: 45);

  /// Loads the standing for the Ranks tab from memory or `standings/current`.
  /// [force] skips memory and forces a fresh server read.
  Future<List<LeaderboardEntry>> load(String tid, {bool force = false}) async {
    if (!force) {
      final at = _memAt[tid];
      final cached = _mem[tid];
      if (at != null &&
          cached != null &&
          DateTime.now().difference(at) < _memTtl) {
        return cached;
      }
    }

    final doc = force
        ? await Refs.standings(tid).get(const GetOptions(source: Source.server))
        : await Refs.standings(tid).get();
    final entries = _entriesFromDoc(doc);
    if (entries == null) {
      throw StateError('Leaderboard standings are not available yet.');
    }
    return _remember(tid, entries);
  }

  /// Stale-while-revalidate stream for the Ranks tab (performance.md Phase 2).
  ///
  /// Emits whatever is available *immediately* — the in-memory cache, then the
  /// Firestore on-disk cache — so the list paints without a network wait, then
  /// emits the authoritative server standing. Repeat visits within a session are
  /// instant; cross-session visits paint from the disk cache first.
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

    // 3. Authoritative server read. If this fails and there was no cached value,
    // surface the error instead of silently issuing one query per finished match.
    try {
      final entries = _entriesFromDoc(
        await Refs.standings(tid).get(const GetOptions(source: Source.server)),
      );
      if (entries != null) {
        yield _remember(tid, entries);
        return;
      }
      if (!emitted) {
        throw StateError('Leaderboard standings are not available yet.');
      }
    } catch (_) {
      if (!emitted) rethrow;
    }
  }

  /// Parses the `entries` array of a `standings/current` doc. An empty array is
  /// valid; null means the backend document is missing or malformed.
  List<LeaderboardEntry>? _entriesFromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    if (!doc.exists) return null;
    final raw = doc.data()?['entries'] as List?;
    if (raw == null) return null;
    return raw
        .map(
          (e) => LeaderboardEntry.fromMap((e as Map).cast<String, dynamic>()),
        )
        .toList();
  }

  List<LeaderboardEntry> _remember(String tid, List<LeaderboardEntry> entries) {
    _mem[tid] = entries;
    _memAt[tid] = DateTime.now();
    return entries;
  }
}
