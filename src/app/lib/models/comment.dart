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
    this.parentId,
    this.votes = 0,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String displayName;
  final String body;
  final String? parentId;
  final int votes;
  final DateTime? createdAt;

  factory CommentModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    return CommentModel(
      id: doc.id,
      userId: (d['userId'] ?? '') as String,
      displayName: (d['displayName'] ?? '') as String,
      body: (d['body'] ?? '') as String,
      parentId: d['parentId'] as String?,
      votes: (d['votes'] ?? 0) as int,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toCreateMap() => <String, dynamic>{
        'userId': userId,
        'displayName': displayName,
        'body': body,
        'parentId': parentId,
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
