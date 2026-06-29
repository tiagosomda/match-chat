import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_match_state.dart';
import 'firestore_refs.dart';

/// Manages per-user reveal state for matches (winner / score / predictions /
/// comments).
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
    return Refs.userMatchStates.where('userId', isEqualTo: uid).snapshots().map(
      (snap) {
        final map = <String, UserMatchState>{};
        for (final doc in snap.docs) {
          final state = UserMatchState.fromDoc(doc);
          map[state.matchId] = state;
        }
        return map;
      },
    );
  }

  /// Streams the reveal state of a set of friends (by uid). Used to count and
  /// list which friends have revealed a match's score. Firestore caps a
  /// `whereIn` at 30 values, which comfortably covers a friends list.
  Stream<List<UserMatchState>> watchFriendsReveals(List<String> friendUids) {
    if (friendUids.isEmpty) {
      return Stream<List<UserMatchState>>.value(const <UserMatchState>[]);
    }
    final capped = friendUids.take(30).toList();
    return Refs.userMatchStates
        .where('userId', whereIn: capped)
        .snapshots()
        .map((snap) => snap.docs.map(UserMatchState.fromDoc).toList());
  }

  Future<void> setReveal(
    String uid,
    String mid, {
    bool? winner,
    bool? score,
    bool? predictions,
    bool? comments,
    bool? goals,
  }) {
    final data = <String, dynamic>{'userId': uid, 'matchId': mid};
    if (winner != null) data['winnerRevealed'] = winner;
    if (score != null) {
      data['scoreRevealed'] = score;
      // Hiding a score restores the bracket's spoiler boundary too, even when
      // the winner had previously been revealed independently.
      if (!score) data['winnerRevealed'] = false;
    }
    if (predictions != null) data['predictionsRevealed'] = predictions;
    if (comments != null) data['commentsRevealed'] = comments;
    if (goals != null) data['goalsRevealed'] = goals;
    return Refs.userMatchState(uid, mid).set(data, SetOptions(merge: true));
  }
}
