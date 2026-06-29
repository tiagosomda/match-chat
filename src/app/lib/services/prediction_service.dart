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

  /// Streams the current user's predictions across every match, keyed by match
  /// id, so the matches list can show "your pick" on each card (#18). Uses a
  /// collection-group query (match ids are globally unique, so the tournament
  /// doesn't need to be part of the key).
  Stream<Map<String, Prediction>> watchMine(String uid) {
    return Refs.db
        .collectionGroup('predictions')
        .where('appId', isEqualTo: Refs.appId)
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map((snap) {
          final map = <String, Prediction>{};
          for (final d in snap.docs) {
            final matchId = d.reference.parent.parent?.id;
            if (matchId != null) map[matchId] = Prediction.fromDoc(d);
          }
          return map;
        });
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
    final data =
        Prediction(
            userId: userId,
            displayName: displayName,
            scoreA: scoreA,
            scoreB: scoreB,
            favoriteTeam: favoriteTeam,
          ).toMap()
          ..['appId'] = Refs.appId
          ..['tournamentId'] = tid;
    batch.set(ref, data);
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
    // Query the predictions that actually exist instead of probing the user's
    // document under every match in the tournament. Tournament id is not stored
    // on legacy prediction documents, so scope the collection-group result by
    // its ancestor path.
    final snap = await Refs.db
        .collectionGroup('predictions')
        .where('appId', isEqualTo: Refs.appId)
        .where('userId', isEqualTo: uid)
        .get();
    final result = <({String matchId, Prediction prediction})>[];
    for (final doc in snap.docs) {
      final matchRef = doc.reference.parent.parent;
      final tournamentRef = matchRef?.parent.parent;
      if (matchRef == null || tournamentRef?.id != tid) continue;
      result.add((matchId: matchRef.id, prediction: Prediction.fromDoc(doc)));
    }
    return result;
  }
}
