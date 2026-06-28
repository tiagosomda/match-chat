import '../models/chat_message.dart';
import 'firestore_refs.dart';

class ChatService {
  static const int pageSize = 100;

  /// A live window of the most recent [limit] messages, **newest-first** so the
  /// Buzz feed can render bottom-anchored (`reverse: true`). Growing [limit] as
  /// the reader scrolls back in time simply widens this descending query;
  /// Firestore serves the extra history largely from its offline cache, so
  /// back-scrolling is cheap while the newest messages stay live.
  Stream<List<ChatMessage>> watchWindow(String tid, {required int limit}) {
    return Refs.chat(tid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(ChatMessage.fromDoc).toList());
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

/// In-memory view state for the Buzz feed that must survive the tab switches
/// which rebuild `ChatScreen` (HomeShell swaps tab bodies, so the State is
/// recreated on every visit). Held for the app session on [AppState] so the
/// reader returns to where they were rather than snapping back to the newest.
class BuzzFeedState {
  /// How many of the most recent messages are currently loaded. Grows by
  /// [ChatService.pageSize] as the reader scrolls back in time, and is kept
  /// across tab switches so re-opening Buzz restores the same depth.
  int windowLimit = ChatService.pageSize;

  /// Last scroll offset, measured from the newest message (the feed is
  /// bottom-anchored). Null until the reader has scrolled this session.
  double? scrollOffset;

  /// The tournament these values belong to; switching tournaments resets them.
  String? tid;

  /// Resets the window/offset when moving to a different tournament.
  void bind(String tournamentId) {
    if (tid == tournamentId) return;
    tid = tournamentId;
    windowLimit = ChatService.pageSize;
    scrollOffset = null;
  }
}
