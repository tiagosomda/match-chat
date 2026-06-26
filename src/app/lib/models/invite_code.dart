import 'package:cloud_firestore/cloud_firestore.dart';

/// A single-use invite code. Redeeming it promotes a user to Participant and
/// records the invite tree via the redeemer's invitedBy field.
/// Stored at match-chat/app/inviteCodes/{id}, with id == the code string.
class InviteCode {
  InviteCode({
    required this.code,
    required this.createdBy,
    this.usedBy,
    this.usedByName,
    this.usedAt,
    this.createdAt,
  });

  final String code;
  final String createdBy;
  final String? usedBy;
  final String? usedByName;
  final DateTime? usedAt;
  final DateTime? createdAt;

  bool get isUsed => usedBy != null;

  factory InviteCode.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    return InviteCode(
      code: (d['code'] ?? doc.id) as String,
      createdBy: (d['createdBy'] ?? '') as String,
      usedBy: d['usedBy'] as String?,
      usedByName: d['usedByName'] as String?,
      usedAt: (d['usedAt'] as Timestamp?)?.toDate(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toCreateMap() => <String, dynamic>{
    'code': code,
    'createdBy': createdBy,
    'usedBy': null,
    'usedByName': null,
    'usedAt': null,
    'createdAt': FieldValue.serverTimestamp(),
  };
}
