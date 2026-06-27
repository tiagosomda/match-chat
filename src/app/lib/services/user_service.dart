import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import 'firestore_refs.dart';

class UserService {
  Future<AppUser?> fetch(String uid) async {
    final doc = await Refs.user(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromDoc(doc);
  }

  Stream<AppUser?> watch(String uid) {
    return Refs.user(
      uid,
    ).snapshots().map((doc) => doc.exists ? AppUser.fromDoc(doc) : null);
  }

  /// Creates the user document if it doesn't yet exist (first sign-in).
  Future<AppUser> ensureUser({
    required String uid,
    required String email,
    required String displayName,
  }) async {
    final ref = Refs.user(uid);
    final existing = await ref.get();
    if (existing.exists) return AppUser.fromDoc(existing);

    final user = AppUser(
      id: uid,
      displayName: displayName,
      email: email,
      isParticipant: false,
      isAdmin: false,
    );
    await ref.set(user.toCreateMap());
    // Return the just-written user directly instead of an extra server read —
    // the live watch will deliver the canonical doc moments later (#7).
    return user;
  }

  /// Updates the display name, stamps when it changed (for the cooldown) and
  /// flags the doc so the backend backfills the name onto the user's existing
  /// chat/comment/prediction messages over time (#14).
  Future<void> updateDisplayName(String uid, String name) {
    return Refs.user(uid).update({
      'displayName': name,
      'nameChangedAt': FieldValue.serverTimestamp(),
      'nameSyncPending': true,
    });
  }

  Future<void> updateFavoriteTeam(String uid, String? team) {
    return Refs.user(uid).update({'favoriteTeam': team});
  }

  Future<void> updatePreferredTournament(String uid, String tournamentId) {
    return Refs.user(uid).update({'preferredTournamentId': tournamentId});
  }

  Future<AppUser?> fetchByName(String displayName) async {
    final q = await Refs.users
        .where('displayName', isEqualTo: displayName)
        .limit(1)
        .get();
    if (q.docs.isEmpty) return null;
    return AppUser.fromDoc(q.docs.first);
  }

  /// Marks [friendId] as a friend of [uid] (stored on the user's own doc).
  Future<void> addFriend(String uid, String friendId) {
    return Refs.user(uid).update({
      'friends': FieldValue.arrayUnion(<String>[friendId]),
    });
  }

  Future<void> removeFriend(String uid, String friendId) {
    return Refs.user(uid).update({
      'friends': FieldValue.arrayRemove(<String>[friendId]),
    });
  }

  /// Fetches user docs by id (e.g. the current user's friends), in batches of
  /// 10 to respect Firestore's whereIn limit.
  Future<List<AppUser>> fetchByIds(List<String> ids) async {
    final result = <AppUser>[];
    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.sublist(i, (i + 10).clamp(0, ids.length));
      if (chunk.isEmpty) continue;
      final snap = await Refs.users
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      result.addAll(snap.docs.map(AppUser.fromDoc));
    }
    return result;
  }
}
