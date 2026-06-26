import 'package:firebase_auth/firebase_auth.dart';

/// Thin wrapper over FirebaseAuth. Google sign-in on web uses the Firebase
/// popup flow (no google_sign_in package needed).
class AuthService {
  AuthService(this._auth);
  final FirebaseAuth _auth;

  User? get currentUser => _auth.currentUser;
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<UserCredential> signInWithEmail(String email, String password) {
    return _auth.signInWithEmailAndPassword(
        email: email.trim(), password: password);
  }

  Future<UserCredential> registerWithEmail(String email, String password) {
    return _auth.createUserWithEmailAndPassword(
        email: email.trim(), password: password);
  }

  Future<UserCredential> signInWithGoogle() {
    final provider = GoogleAuthProvider();
    provider.setCustomParameters({'prompt': 'select_account'});
    return _auth.signInWithPopup(provider);
  }

  /// Signs in anonymously so a guest can browse the schedule without an account.
  /// Requires the Anonymous provider to be enabled in Firebase Auth.
  Future<UserCredential> signInAnonymously() => _auth.signInAnonymously();

  Future<void> signOut() => _auth.signOut();

  /// Maps FirebaseAuthException codes to friendly messages.
  static String describeError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-email':
          return 'That email address looks invalid.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Incorrect email or password.';
        case 'email-already-in-use':
          return 'An account already exists for that email.';
        case 'weak-password':
          return 'Please choose a stronger password.';
        case 'popup-closed-by-user':
        case 'cancelled-popup-request':
          return 'Sign-in was cancelled.';
        case 'operation-not-allowed':
          return 'This sign-in method is not enabled for the project.';
        default:
          return e.message ?? 'Authentication failed (${e.code}).';
      }
    }
    return 'Something went wrong. Please try again.';
  }
}
