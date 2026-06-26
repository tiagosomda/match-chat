import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/match.dart';
import 'firestore_refs.dart';

class MatchService {
  Stream<List<MatchModel>> watchAll(String tid) {
    return Refs.matches(tid)
        .orderBy('scheduledAt')
        .snapshots()
        .map((snap) => snap.docs.map(MatchModel.fromDoc).toList());
  }

  Stream<MatchModel?> watch(String tid, String mid) {
    return Refs.match(
      tid,
      mid,
    ).snapshots().map((doc) => doc.exists ? MatchModel.fromDoc(doc) : null);
  }

  Future<MatchModel?> fetch(String tid, String mid) async {
    final doc = await Refs.match(tid, mid).get();
    if (!doc.exists) return null;
    return MatchModel.fromDoc(doc);
  }

  /// Admin: create a match. Returns the new id.
  Future<String> create({
    required String tid,
    required String teamA,
    required String teamB,
    required String description,
    DateTime? scheduledAt,
    String? venue,
    String? city,
  }) async {
    final ref = await Refs.matches(tid).add(<String, dynamic>{
      'teamA': teamA,
      'teamB': teamB,
      'description': description,
      'status': MatchStatus.upcoming.id,
      'scoreA': null,
      'scoreB': null,
      'scheduledAt': scheduledAt == null
          ? null
          : Timestamp.fromDate(scheduledAt),
      'venue': venue,
      'city': city,
      'commentCount': 0,
      'predictionCount': 0,
      'archived': false,
    });
    return ref.id;
  }

  /// Admin: update editable match fields.
  Future<void> update({
    required String tid,
    required String mid,
    required String teamA,
    required String teamB,
    required String description,
    required MatchStatus status,
    DateTime? scheduledAt,
    int? scoreA,
    int? scoreB,
    String? venue,
    String? city,
  }) {
    return Refs.match(tid, mid).update(<String, dynamic>{
      'teamA': teamA,
      'teamB': teamB,
      'description': description,
      'status': status.id,
      'scheduledAt': scheduledAt == null
          ? null
          : Timestamp.fromDate(scheduledAt),
      'scoreA': scoreA,
      'scoreB': scoreB,
      'venue': venue,
      'city': city,
    });
  }

  Future<void> setArchived(String tid, String mid, bool archived) {
    return Refs.match(tid, mid).update({'archived': archived});
  }
}
