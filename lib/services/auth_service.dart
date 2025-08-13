// lib/services/auth_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart' show immutable, kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// Optional (Google Sign-In)
// If you do not plan to use Google login, you can remove this import and related methods.
import 'package:google_sign_in/google_sign_in.dart';

/// Unified exception for the app's auth layer.
/// Always catch this instead of FirebaseAuthException in UI code.
@immutable
class AuthException implements Exception {
  final String code;     // A stable error code to branch on in the UI
  final String message;  // A human-readable message
  const AuthException(this.code, this.message);

  @override
  String toString() => 'AuthException($code): $message';
}

/// A thin domain layer on top of FirebaseAuth with unified errors.
/// - Supports: anonymous, email/password, Google sign-in
/// - Provides: auth state stream, token, profile updates, reauth, delete
class AuthService {
  AuthService._internal({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  static final AuthService _instance = AuthService._internal();

  /// Global singleton instance.
  factory AuthService() => _instance;

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  /// Stream that emits on login/logout and when the current user changes.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Stream that emits when ID token is refreshed/changed.
  Stream<User?> get idTokenChanges => _auth.idTokenChanges();

  /// Returns the current Firebase user or null.
  User? get currentUser => _auth.currentUser;

  /// Syntactic sugar getter: whether user is signed in.
  bool get isSignedIn => currentUser != null;

  /// Current UID if signed in, otherwise null.
  String? get uid => currentUser?.uid;

  // ---------------------------------------------------------------------------
  // Sign-in / Sign-up
  // ---------------------------------------------------------------------------

  /// Anonymous sign-in (useful for quick start before full registration).
  Future<UserCredential> signInAnonymously() async {
    try {
      return await _auth.signInAnonymously();
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    } catch (e) {
      throw const AuthException('unknown', 'Failed to sign in anonymously.');
    }
  }

  /// Email/password registration.
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      // Optionally set display name
      if (displayName != null && displayName.trim().isNotEmpty) {
        await cred.user?.updateDisplayName(displayName.trim());
      }
      return cred;
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    } catch (_) {
      throw const AuthException('unknown', 'Failed to create an account.');
    }
  }

  /// Email/password login.
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    } catch (_) {
      throw const AuthException('unknown', 'Failed to sign in with email.');
    }
  }

  /// Google Sign-In (works on Android/iOS/Web).
  Future<UserCredential> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // Web: use popup flow
        final googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        return await _auth.signInWithPopup(googleProvider);
      } else {
        // Mobile: use google_sign_in package to acquire tokens, then authenticate
        final GoogleSignInAccount? gUser = await _googleSignIn.signIn();
        if (gUser == null) {
          throw const AuthException('cancelled', 'Google sign-in was cancelled.');
        }
        final GoogleSignInAuthentication gAuth = await gUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: gAuth.accessToken,
          idToken: gAuth.idToken,
        );
        return await _auth.signInWithCredential(credential);
      }
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException('unknown', 'Failed to sign in with Google.');
    }
  }

  // ---------------------------------------------------------------------------
  // Password / Email utilities
  // ---------------------------------------------------------------------------

  /// Sends a verification email to current user (if any).
  Future<void> sendEmailVerification() async {
    try {
      final u = _auth.currentUser;
      if (u == null) {
        throw const AuthException('no-user', 'No signed-in user.');
      }
      if (!u.emailVerified) {
        await u.sendEmailVerification();
      }
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException('unknown', 'Failed to send verification email.');
    }
  }

  /// Sends password reset email.
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    } catch (_) {
      throw const AuthException('unknown', 'Failed to send password reset email.');
    }
  }

  // ---------------------------------------------------------------------------
  // Profile updates
  // ---------------------------------------------------------------------------

  /// Update display name for current user.
  Future<void> updateDisplayName(String name) async {
    try {
      final u = _auth.currentUser;
      if (u == null) {
        throw const AuthException('no-user', 'No signed-in user.');
      }
      await u.updateDisplayName(name.trim());
      await u.reload();
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException('unknown', 'Failed to update display name.');
    }
  }

  /// Update photo URL for current user.
  Future<void> updatePhotoURL(String url) async {
    try {
      final u = _auth.currentUser;
      if (u == null) {
        throw const AuthException('no-user', 'No signed-in user.');
      }
      await u.updatePhotoURL(url.trim());
      await u.reload();
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException('unknown', 'Failed to update photo URL.');
    }
  }

  // ---------------------------------------------------------------------------
  // Token / Reauth / Delete / Sign out
  // ---------------------------------------------------------------------------

  /// Returns a JWT ID token for the current user.
  Future<String> getIdToken({bool forceRefresh = false}) async {
    try {
      final u = _auth.currentUser;
      if (u == null) {
        throw const AuthException('no-user', 'No signed-in user.');
      }
      final token = await u.getIdToken(forceRefresh);
      return token ?? '';
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException('unknown', 'Failed to get ID token.');
    }
  }

  /// Reauthenticate with email/password (required for sensitive actions).
  Future<void> reauthenticateWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final u = _auth.currentUser;
      if (u == null) {
        throw const AuthException('no-user', 'No signed-in user.');
      }
      final cred = EmailAuthProvider.credential(
        email: email.trim(),
        password: password,
      );
      await u.reauthenticateWithCredential(cred);
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException('unknown', 'Failed to reauthenticate.');
    }
  }

  /// Sign out from Firebase (and Google if used).
  Future<void> signOut() async {
    try {
      // Sign out of both providers to be clean.
      if (!kIsWeb) {
        await _googleSignIn.signOut().catchError((_) {});
      }
      await _auth.signOut();
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    } catch (_) {
      throw const AuthException('unknown', 'Failed to sign out.');
    }
  }

  /// Permanently delete the current account (requires recent login).
  Future<void> deleteAccount() async {
    try {
      final u = _auth.currentUser;
      if (u == null) {
        throw const AuthException('no-user', 'No signed-in user.');
      }
      await u.delete();
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException('unknown', 'Failed to delete account.');
    }
  }

  // ---------------------------------------------------------------------------
  // Error mapping
  // ---------------------------------------------------------------------------

  /// Normalize FirebaseAuthException to AuthException with stable codes.
  AuthException _mapAuthError(FirebaseAuthException e) {
    // Map Firebase codes to your domain codes & friendly messages.
    switch (e.code) {
      case 'invalid-email':
        return const AuthException('invalid-email', 'The email address is invalid.');
      case 'user-disabled':
        return const AuthException('user-disabled', 'This user account has been disabled.');
      case 'user-not-found':
        return const AuthException('user-not-found', 'No user found with this email.');
      case 'wrong-password':
        return const AuthException('wrong-password', 'Incorrect password.');
      case 'email-already-in-use':
        return const AuthException('email-in-use', 'This email is already in use.');
      case 'weak-password':
        return const AuthException('weak-password', 'The password is too weak.');
      case 'operation-not-allowed':
        return const AuthException('op-not-allowed', 'This auth method is not allowed.');
      case 'network-request-failed':
        return const AuthException('network', 'Network error. Check your connection.');
      case 'popup-closed-by-user':
        return const AuthException('cancelled', 'The popup was closed before completing sign-in.');
      case 'account-exists-with-different-credential':
        return const AuthException(
          'account-exists-with-different-credential',
          'An account already exists with a different sign-in method.',
        );
      case 'requires-recent-login':
        return const AuthException(
          'requires-recent-login',
          'Please reauthenticate and try again.',
        );
      default:
        // Include original code for debugging; do NOT leak internal messages to end users.
        debugPrint('FirebaseAuthException: ${e.code} / ${e.message}');
        return AuthException(e.code, 'Authentication failed. (${e.code})');
    }
  }
}

