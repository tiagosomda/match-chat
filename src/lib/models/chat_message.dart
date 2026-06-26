import 'package:cloud_firestore/cloud_firestore.dart';

/// A global chat message for a tournament. May optionally be tagged to a match
/// via [matchId] (null = general). Stored at
/// match-chat/app/tournaments/{tid}/chat/{id}.
class ChatMessage {
  ChatMessage({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.body,
    this.matchId,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String displayName;
  final String body;
  final String? matchId;
  final DateTime? createdAt;

  factory ChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    return ChatMessage(
      id: doc.id,
      userId: (d['userId'] ?? '') as String,
      displayName: (d['displayName'] ?? '') as String,
      body: (d['body'] ?? '') as String,
      matchId: d['matchId'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toCreateMap() => <String, dynamic>{
        'userId': userId,
        'displayName': displayName,
        'body': body,
        'matchId': matchId,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
