import 'package:cloud_firestore/cloud_firestore.dart';

/// A registered user. Stored at match-chat/app/users/{uid}.
class AppUser {
  AppUser({
    required this.id,
    required this.displayName,
    required this.email,
    required this.isParticipant,
    required this.isAdmin,
    this.invitedBy,
    this.favoriteTeam,
    this.preferredTournamentId,
    this.friends = const <String>[],
    this.createdAt,
  });

  final String id;
  final String displayName;
  final String email;
  final bool isParticipant;
  final bool isAdmin;
  final String? invitedBy;
  final String? favoriteTeam;
  final String? preferredTournamentId;

  /// UIDs the user has marked as friends.
  final List<String> friends;
  final DateTime? createdAt;

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    return AppUser(
      id: doc.id,
      displayName: (d['displayName'] ?? '') as String,
      email: (d['email'] ?? '') as String,
      isParticipant: (d['isParticipant'] ?? false) as bool,
      isAdmin: (d['isAdmin'] ?? false) as bool,
      invitedBy: d['invitedBy'] as String?,
      favoriteTeam: d['favoriteTeam'] as String?,
      preferredTournamentId: d['preferredTournamentId'] as String?,
      friends: (d['friends'] as List?)?.cast<String>() ?? const <String>[],
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toCreateMap() => <String, dynamic>{
    'displayName': displayName,
    'email': email,
    'isParticipant': isParticipant,
    'isAdmin': isAdmin,
    'invitedBy': invitedBy,
    'favoriteTeam': favoriteTeam,
    'preferredTournamentId': preferredTournamentId,
    'friends': friends,
    'createdAt': FieldValue.serverTimestamp(),
  };

  bool isFriend(String uid) => friends.contains(uid);

  AppUser copyWith({
    String? displayName,
    bool? isParticipant,
    String? favoriteTeam,
    bool clearFavoriteTeam = false,
    String? preferredTournamentId,
    List<String>? friends,
  }) {
    return AppUser(
      id: id,
      displayName: displayName ?? this.displayName,
      email: email,
      isParticipant: isParticipant ?? this.isParticipant,
      isAdmin: isAdmin,
      invitedBy: invitedBy,
      favoriteTeam: clearFavoriteTeam
          ? null
          : (favoriteTeam ?? this.favoriteTeam),
      preferredTournamentId:
          preferredTournamentId ?? this.preferredTournamentId,
      friends: friends ?? this.friends,
      createdAt: createdAt,
    );
  }
}
