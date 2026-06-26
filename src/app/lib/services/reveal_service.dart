import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_match_state.dart';
import 'firestore_refs.dart';

/// Manages per-user reveal state for matches (score / predictions / comments).
class RevealService {
  Stream<UserMatchState> watch(String uid, String mid) {
    return Refs.userMatchState(uid, mid).snapshots().map((doc) {
      if (!doc.exists) {
        return UserMatchState(userId: uid, matchId: mid);
      }
      return UserMatchState.fromDoc(doc);
    });
  }

  /// Streams the reveal state for many matches at once (used by the match list
  /// and chat to know which match-tagged content can be unblurred).
  Stream<Map<String, UserMatchState>> watchAllForUser(String uid) {
    return Refs.userMatchStates
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map((snap) {
      final map = <String, UserMatchState>{};
      for (final doc in snap.docs) {
        final state = UserMatchState.fromDoc(doc);
        map[state.matchId] = state;
      }
      return map;
    });
  }

  Future<void> setReveal(
    String uid,
    String mid, {
    bool? score,
    bool? predictions,
    bool? comments,
  }) {
    final data = <String, dynamic>{
      'userId': uid,
      'matchId': mid,
    };
    if (score != null) data['scoreRevealed'] = score;
    if (predictions != null) data['predictionsRevealed'] = predictions;
    if (comments != null) data['commentsRevealed'] = comments;
    return Refs.userMatchState(uid, mid).set(data, SetOptions(merge: true));
  }
}
