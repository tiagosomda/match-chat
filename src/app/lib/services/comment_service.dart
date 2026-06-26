import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/comment.dart';
import 'firestore_refs.dart';

class CommentService {
  Stream<List<CommentModel>> watch(String tid, String mid) {
    return Refs.comments(tid, mid)
        .orderBy('createdAt')
        .snapshots()
        .map((snap) => snap.docs.map(CommentModel.fromDoc).toList());
  }

  /// Posts a comment (or reply when [parentId] is set) and bumps the match's
  /// cached commentCount in a single batch.
  Future<void> post({
    required String tid,
    required String mid,
    required String userId,
    required String displayName,
    required String body,
    String? favoriteTeam,
    String? parentId,
  }) async {
    final batch = Refs.db.batch();
    final commentRef = Refs.comments(tid, mid).doc();
    batch.set(
      commentRef,
      CommentModel(
        id: commentRef.id,
        userId: userId,
        displayName: displayName,
        body: body,
        favoriteTeam: favoriteTeam,
        parentId: parentId,
      ).toCreateMap(),
    );
    batch.update(Refs.match(tid, mid), {
      'commentCount': FieldValue.increment(1),
    });
    await batch.commit();
  }

  /// Edits a comment's body (owner only — enforced by rules). Stamps editedAt.
  Future<void> edit({
    required String tid,
    required String mid,
    required String commentId,
    required String body,
  }) {
    return Refs.comments(tid, mid).doc(commentId).update(<String, dynamic>{
      'body': body,
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Soft-deletes a comment: keeps the doc (so replies stay anchored) but
  /// clears the body and records who removed it ('user' or 'admin').
  Future<void> softDelete({
    required String tid,
    required String mid,
    required String commentId,
    required bool byAdmin,
  }) {
    return Refs.comments(tid, mid).doc(commentId).update(<String, dynamic>{
      'deleted': true,
      'deletedBy': byAdmin ? 'admin' : 'user',
      'body': '',
    });
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
