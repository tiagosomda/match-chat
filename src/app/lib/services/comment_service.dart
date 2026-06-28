import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/chat_message.dart';
import '../models/comment.dart';
import 'firestore_refs.dart';

class CommentService {
  Stream<List<CommentModel>> watch(String tid, String mid) {
    return Refs.comments(tid, mid)
        .orderBy('createdAt')
        .snapshots()
        .map((snap) => snap.docs.map(CommentModel.fromDoc).toList());
  }

  /// Posts a comment (or reply when [parentId] is set), mirrors it into the
  /// tournament's Buzz feed (the `chat` collection, tagged with [mid]), and
  /// bumps the match's cached commentCount — all in a single atomic batch.
  ///
  /// The mirror is what surfaces on the read-only Buzz tab; the comment stores
  /// the mirror's id ([CommentModel.chatMsgId]) so later edits/deletes can keep
  /// the two in sync.
  Future<void> post({
    required String tid,
    required String mid,
    required String userId,
    required String displayName,
    required String body,
    String? favoriteTeam,
    String? parentId,
    String? parentUserId,
    String? parentName,
  }) async {
    final batch = Refs.db.batch();
    final commentRef = Refs.comments(tid, mid).doc();
    final chatRef = Refs.chat(tid).doc();
    final isReply = parentId != null;
    batch.set(
      commentRef,
      CommentModel(
        id: commentRef.id,
        userId: userId,
        displayName: displayName,
        body: body,
        favoriteTeam: favoriteTeam,
        parentId: parentId,
        chatMsgId: chatRef.id,
      ).toCreateMap(),
    );
    batch.set(
      chatRef,
      ChatMessage(
        id: chatRef.id,
        userId: userId,
        displayName: displayName,
        body: body,
        favoriteTeam: favoriteTeam,
        matchId: mid,
        // Carry the parent author onto the Buzz mirror so the feed can flag
        // replies aimed at the viewer.
        replyToUserId: isReply ? parentUserId : null,
        replyToName: isReply ? parentName : null,
      ).toCreateMap(),
    );
    batch.update(Refs.match(tid, mid), {
      'commentCount': FieldValue.increment(1),
    });
    await batch.commit();
  }

  /// Edits a comment's body (owner only — enforced by rules). Stamps editedAt
  /// and updates the mirrored Buzz message when [chatMsgId] is known.
  Future<void> edit({
    required String tid,
    required String mid,
    required String commentId,
    required String body,
    String? chatMsgId,
  }) {
    final batch = Refs.db.batch();
    batch.update(Refs.comments(tid, mid).doc(commentId), <String, dynamic>{
      'body': body,
      'editedAt': FieldValue.serverTimestamp(),
    });
    if (chatMsgId != null) {
      batch.update(Refs.chat(tid).doc(chatMsgId), <String, dynamic>{
        'body': body,
      });
    }
    return batch.commit();
  }

  /// Soft-deletes a comment: keeps the doc (so replies stay anchored) but
  /// clears the body and records who removed it ('user' or 'admin'). The
  /// mirrored Buzz message is removed outright so it drops out of the feed.
  Future<void> softDelete({
    required String tid,
    required String mid,
    required String commentId,
    required bool byAdmin,
    String? chatMsgId,
  }) {
    final batch = Refs.db.batch();
    batch.update(Refs.comments(tid, mid).doc(commentId), <String, dynamic>{
      'deleted': true,
      'deletedBy': byAdmin ? 'admin' : 'user',
      'body': '',
    });
    if (chatMsgId != null) {
      batch.delete(Refs.chat(tid).doc(chatMsgId));
    }
    return batch.commit();
  }

  /// Builds an ordered, indented tree from a flat comment list.
  static List<CommentNode> buildTree(List<CommentModel> comments) {
    final byParent = <String?, List<CommentModel>>{};
    for (final c in comments) {
      byParent.putIfAbsent(c.parentId, () => <CommentModel>[]).add(c);
    }
    final result = <CommentNode>[];

    void walk(String? parentId, int depth) {
      final children = byParent[parentId] ?? const <CommentModel>[];
      for (final c in children) {
        final node = CommentNode(c, depth);
        result.add(node);
        walk(c.id, depth + 1);
      }
    }

    walk(null, 0);
    return result;
  }
}
