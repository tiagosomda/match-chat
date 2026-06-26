import '../models/tournament.dart';
import 'firestore_refs.dart';

class TournamentService {
  Stream<List<Tournament>> watchAll() {
    return Refs.tournaments
        .orderBy('order')
        .snapshots()
        .map((snap) => snap.docs.map(Tournament.fromDoc).toList());
  }

  Future<List<Tournament>> fetchAll() async {
    final snap = await Refs.tournaments.orderBy('order').get();
    return snap.docs.map(Tournament.fromDoc).toList();
  }

  Future<Tournament?> fetch(String id) async {
    final doc = await Refs.tournament(id).get();
    if (!doc.exists) return null;
    return Tournament.fromDoc(doc);
  }

  /// Picks the tournament to load into: the user's preferred one if it still
  /// exists, otherwise the default, otherwise the first available.
  Future<Tournament?> resolveInitial(String? preferredId) async {
    final all = await fetchAll();
    if (all.isEmpty) return null;
    if (preferredId != null) {
      for (final t in all) {
        if (t.id == preferredId) return t;
      }
    }
    for (final t in all) {
      if (t.isDefault) return t;
    }
    return all.first;
  }
}
