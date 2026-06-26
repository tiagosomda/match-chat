import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/prediction.dart';
import 'firestore_refs.dart';

class PredictionService {
  Stream<List<Prediction>> watch(String tid, String mid) {
    return Refs.predictions(tid, mid)
        .orderBy('createdAt')
        .snapshots()
        .map((snap) => snap.docs.map(Prediction.fromDoc).toList());
  }

  Future<Prediction?> fetchForUser(String tid, String mid, String uid) async {
    final doc = await Refs.predictions(tid, mid).doc(uid).get();
    if (!doc.exists) return null;
    return Prediction.fromDoc(doc);
  }

  /// Submits the current user's prediction. Document id is the userId so each
  /// user has at most one prediction per match. Bumps predictionCount on first
  /// submission.
  Future<void> submit({
    required String tid,
    required String mid,
    required String userId,
    required String displayName,
    required int scoreA,
    required int scoreB,
    String? favoriteTeam,
  }) async {
    final ref = Refs.predictions(tid, mid).doc(userId);
    final existing = await ref.get();
    final batch = Refs.db.batch();
    batch.set(
      ref,
      Prediction(
        userId: userId,
        displayName: displayName,
        scoreA: scoreA,
        scoreB: scoreB,
        favoriteTeam: favoriteTeam,
      ).toMap(),
    );
    if (!existing.exists) {
      batch.update(Refs.match(tid, mid), {
        'predictionCount': FieldValue.increment(1),
      });
    }
    await batch.commit();
  }

  /// Removes the current user's prediction and decrements the cached
  /// predictionCount. No-op if there's nothing to delete.
  Future<void> delete({
    required String tid,
    required String mid,
    required String userId,
  }) async {
    final ref = Refs.predictions(tid, mid).doc(userId);
    final existing = await ref.get();
    if (!existing.exists) return;
    final batch = Refs.db.batch();
    batch.delete(ref);
    batch.update(Refs.match(tid, mid), {
      'predictionCount': FieldValue.increment(-1),
    });
    await batch.commit();
  }

  /// Fetches every prediction a user has made across a tournament, for their
  /// public profile.
  Future<List<({String matchId, Prediction prediction})>> fetchForUserAcross(
    String tid,
    String uid,
  ) async {
    final matchesSnap = await Refs.matches(tid).get();
    final result = <({String matchId, Prediction prediction})>[];
    for (final m in matchesSnap.docs) {
      final p = await Refs.predictions(tid, m.id).doc(uid).get();
      if (p.exists) {
        result.add((matchId: m.id, prediction: Prediction.fromDoc(p)));
      }
    }
    return result;
  }
}
