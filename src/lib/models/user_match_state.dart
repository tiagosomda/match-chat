import 'package:cloud_firestore/cloud_firestore.dart';

/// Tracks one user's per-match reveal state (score / predictions / comments).
/// Document id is the compound key `{userId}_{matchId}`.
/// Stored at match-chat/app/userMatchStates/{userId}_{matchId}.
class UserMatchState {
  UserMatchState({
    required this.userId,
    required this.matchId,
    this.scoreRevealed = false,
    this.predictionsRevealed = false,
    this.commentsRevealed = false,
  });

  final String userId;
  final String matchId;
  final bool scoreRevealed;
  final bool predictionsRevealed;
  final bool commentsRevealed;

  static String docId(String userId, String matchId) => '${userId}_$matchId';

  factory UserMatchState.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    return UserMatchState(
      userId: (d['userId'] ?? '') as String,
      matchId: (d['matchId'] ?? '') as String,
      scoreRevealed: (d['scoreRevealed'] ?? false) as bool,
      predictionsRevealed: (d['predictionsRevealed'] ?? false) as bool,
      commentsRevealed: (d['commentsRevealed'] ?? false) as bool,
    );
  }
}
