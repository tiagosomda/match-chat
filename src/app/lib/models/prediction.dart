import 'package:cloud_firestore/cloud_firestore.dart';

/// A score prediction. One per user per match — the document id is the userId.
/// Stored at match-chat/app/tournaments/{tid}/matches/{mid}/predictions/{uid}.
class Prediction {
  Prediction({
    required this.userId,
    required this.displayName,
    required this.scoreA,
    required this.scoreB,
    this.favoriteTeam,
    this.createdAt,
  });

  final String userId;
  final String displayName;
  final int scoreA;
  final int scoreB;
  final String? favoriteTeam;
  final DateTime? createdAt;

  String get scoreText => '$scoreA : $scoreB';

  factory Prediction.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    return Prediction(
      userId: (d['userId'] ?? doc.id) as String,
      displayName: (d['displayName'] ?? '') as String,
      scoreA: (d['scoreA'] ?? 0) as int,
      scoreB: (d['scoreB'] ?? 0) as int,
      favoriteTeam: d['favoriteTeam'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'userId': userId,
    'displayName': displayName,
    'scoreA': scoreA,
    'scoreB': scoreB,
    if (favoriteTeam != null) 'favoriteTeam': favoriteTeam,
    'createdAt': FieldValue.serverTimestamp(),
  };
}
