/// Authentication for the couples app (Firebase Auth, email +
/// password).
///
/// The app depends on the abstract [AuthService], not on
/// firebase_auth directly, so the auth gate in `main.dart` can be
/// widget-tested with a fake and so local-backend mode never
/// touches Firebase at all.
library;

import 'package:firebase_auth/firebase_auth.dart';

/// A signed-in user, reduced to what the app needs.
class AuthUser {
  const AuthUser({required this.uid, this.email});
  final String uid;
  final String? email;
}

abstract class AuthService {
  /// Emits the current user on sign-in / sign-out (and once at
  /// startup with the restored session, or null).
  Stream<AuthUser?> get userChanges;

  AuthUser? get currentUser;

  Future<void> signIn(String email, String password);
  Future<void> signUp(String email, String password);
  Future<void> signOut();
}

class FirebaseAuthService implements AuthService {
  FirebaseAuthService([FirebaseAuth? auth]) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  AuthUser? _map(User? u) =>
      u == null ? null : AuthUser(uid: u.uid, email: u.email);

  @override
  Stream<AuthUser?> get userChanges => _auth.authStateChanges().map(_map);

  @override
  AuthUser? get currentUser => _map(_auth.currentUser);

  @override
  Future<void> signIn(String email, String password) => _auth
      .signInWithEmailAndPassword(email: email.trim(), password: password);

  @override
  Future<void> signUp(String email, String password) => _auth
      .createUserWithEmailAndPassword(email: email.trim(), password: password);

  @override
  Future<void> signOut() => _auth.signOut();
}

/// Turns FirebaseAuth error codes into words a tired parent can act
/// on at 3 AM. Falls back to the raw message for unknown errors.
String friendlyAuthError(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'invalid-email':
        return 'That email address doesn\'t look right.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email or password doesn\'t match. Try again.';
      case 'email-already-in-use':
        return 'That email already has an account — try signing in instead.';
      case 'weak-password':
        return 'Password is too weak — use at least 6 characters.';
      case 'network-request-failed':
        return 'No connection. Check your internet and try again.';
      case 'too-many-requests':
        return 'Too many tries — wait a bit and try again.';
      default:
        return error.message ?? 'Sign-in failed (${error.code}).';
    }
  }
  return 'Something went wrong: $error';
}
