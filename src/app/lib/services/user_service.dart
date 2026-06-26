import '../models/app_user.dart';
import 'firestore_refs.dart';

class UserService {
  Future<AppUser?> fetch(String uid) async {
    final doc = await Refs.user(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromDoc(doc);
  }

  Stream<AppUser?> watch(String uid) {
    return Refs.user(uid).snapshots().map(
          (doc) => doc.exists ? AppUser.fromDoc(doc) : null,
        );
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
    final created = await ref.get();
    return AppUser.fromDoc(created);
  }

  Future<void> updateDisplayName(String uid, String name) {
    return Refs.user(uid).update({'displayName': name});
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
}
