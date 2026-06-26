import '../models/chat_message.dart';
import 'firestore_refs.dart';

class ChatService {
  static const int pageSize = 100;

  Stream<List<ChatMessage>> watch(String tid) {
    // Order descending and take the latest N, then the UI reverses for display.
    return Refs.chat(tid)
        .orderBy('createdAt', descending: true)
        .limit(pageSize)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map(ChatMessage.fromDoc).toList().reversed.toList(),
        );
  }

  Future<void> send({
    required String tid,
    required String userId,
    required String displayName,
    required String body,
    String? favoriteTeam,
    String? matchId,
  }) {
    return Refs.chat(tid).add(
      ChatMessage(
        id: '',
        userId: userId,
        displayName: displayName,
        body: body,
        favoriteTeam: favoriteTeam,
        matchId: matchId,
      ).toCreateMap(),
    );
  }
}
