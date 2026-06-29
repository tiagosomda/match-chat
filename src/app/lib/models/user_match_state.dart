import 'package:cloud_firestore/cloud_firestore.dart';

/// Tracks one user's per-match reveal state (winner / score / predictions /
/// comments).
/// Document id is the compound key `{userId}_{matchId}`.
/// Stored at match-chat/app/userMatchStates/{userId}_{matchId}.
class UserMatchState {
  UserMatchState({
    required this.userId,
    required this.matchId,
    this.winnerRevealed = false,
    this.scoreRevealed = false,
    this.predictionsRevealed = false,
    this.commentsRevealed = false,
    this.goalsRevealed = false,
  });

  final String userId;
  final String matchId;
  final bool winnerRevealed;
  final bool scoreRevealed;
  final bool predictionsRevealed;
  final bool commentsRevealed;
  final bool goalsRevealed;

  static String docId(String userId, String matchId) => '${userId}_$matchId';

  factory UserMatchState.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    return UserMatchState(
      userId: (d['userId'] ?? '') as String,
      matchId: (d['matchId'] ?? '') as String,
      winnerRevealed: (d['winnerRevealed'] ?? false) as bool,
      scoreRevealed: (d['scoreRevealed'] ?? false) as bool,
      predictionsRevealed: (d['predictionsRevealed'] ?? false) as bool,
      commentsRevealed: (d['commentsRevealed'] ?? false) as bool,
      goalsRevealed: (d['goalsRevealed'] ?? false) as bool,
    );
  }
}
