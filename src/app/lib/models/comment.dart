import 'package:cloud_firestore/cloud_firestore.dart';

/// A comment on a match thread. Supports one level of threaded replies via
/// [parentId] (null = top-level). Stored at
/// match-chat/app/tournaments/{tid}/matches/{mid}/comments/{id}.
class CommentModel {
  CommentModel({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.body,
    this.favoriteTeam,
    this.parentId,
    this.chatMsgId,
    this.votes = 0,
    this.deleted = false,
    this.deletedBy,
    this.createdAt,
    this.editedAt,
  });

  final String id;
  final String userId;
  final String displayName;
  final String body;
  final String? favoriteTeam;
  final String? parentId;

  /// Id of the mirrored message in the tournament's Buzz feed (`chat`
  /// collection). Set when the comment is posted so edits/deletes can keep the
  /// Buzz copy in sync. Null for comments created before the Buzz projection
  /// existed — those simply have no feed entry to update.
  final String? chatMsgId;

  final int votes;

  /// Soft-delete: the doc is kept (so replies stay anchored) but the body is
  /// cleared and a placeholder is shown. [deletedBy] is 'user' or 'admin'.
  final bool deleted;
  final String? deletedBy;
  final DateTime? createdAt;
  final DateTime? editedAt;

  bool get edited => editedAt != null;

  factory CommentModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    return CommentModel(
      id: doc.id,
      userId: (d['userId'] ?? '') as String,
      displayName: (d['displayName'] ?? '') as String,
      body: (d['body'] ?? '') as String,
      favoriteTeam: d['favoriteTeam'] as String?,
      parentId: d['parentId'] as String?,
      chatMsgId: d['chatMsgId'] as String?,
      votes: (d['votes'] ?? 0) as int,
      deleted: (d['deleted'] ?? false) as bool,
      deletedBy: d['deletedBy'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      editedAt: (d['editedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toCreateMap() => <String, dynamic>{
    'userId': userId,
    'displayName': displayName,
    'body': body,
    if (favoriteTeam != null) 'favoriteTeam': favoriteTeam,
    'parentId': parentId,
    if (chatMsgId != null) 'chatMsgId': chatMsgId,
    'votes': 0,
    'createdAt': FieldValue.serverTimestamp(),
  };
}

/// A comment plus its nested replies, used for rendering the thread tree.
class CommentNode {
  CommentNode(this.comment, this.depth);
  final CommentModel comment;
  final int depth;
  final List<CommentNode> children = <CommentNode>[];

  int get descendantCount {
    var n = 0;
    for (final c in children) {
      n += 1 + c.descendantCount;
    }
    return n;
  }
}
