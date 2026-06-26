import 'package:cloud_firestore/cloud_firestore.dart';

/// Centralized Firestore paths.
///
/// Everything lives under the top-level `match-chat` collection (see
/// docs/firebase.md) because the database is shared with other projects. We use
/// a single app document `match-chat/app` and hang all entity collections off
/// it, so a single security rule on `/match-chat/{document=**}` covers the app.
class Refs {
  Refs._();

  static FirebaseFirestore get db => FirebaseFirestore.instance;

  /// The single application root document: match-chat/app
  static DocumentReference<Map<String, dynamic>> get appDoc =>
      db.collection('match-chat').doc('app');

  static CollectionReference<Map<String, dynamic>> get users =>
      appDoc.collection('users');

  static DocumentReference<Map<String, dynamic>> user(String uid) =>
      users.doc(uid);

  static CollectionReference<Map<String, dynamic>> get tournaments =>
      appDoc.collection('tournaments');

  static DocumentReference<Map<String, dynamic>> tournament(String tid) =>
      tournaments.doc(tid);

  static CollectionReference<Map<String, dynamic>> matches(String tid) =>
      tournament(tid).collection('matches');

  static DocumentReference<Map<String, dynamic>> match(
    String tid,
    String mid,
  ) => matches(tid).doc(mid);

  static CollectionReference<Map<String, dynamic>> comments(
    String tid,
    String mid,
  ) => match(tid, mid).collection('comments');

  static CollectionReference<Map<String, dynamic>> predictions(
    String tid,
    String mid,
  ) => match(tid, mid).collection('predictions');

  static CollectionReference<Map<String, dynamic>> chat(String tid) =>
      tournament(tid).collection('chat');

  static CollectionReference<Map<String, dynamic>> get inviteCodes =>
      appDoc.collection('inviteCodes');

  static DocumentReference<Map<String, dynamic>> inviteCode(String code) =>
      inviteCodes.doc(code);

  static CollectionReference<Map<String, dynamic>> get userMatchStates =>
      appDoc.collection('userMatchStates');

  static DocumentReference<Map<String, dynamic>> userMatchState(
    String uid,
    String mid,
  ) => userMatchStates.doc('${uid}_$mid');
}
