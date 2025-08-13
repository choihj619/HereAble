// lib/providers/user_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_profile.dart';
import '../services/auth_service.dart';

/// UserProvider manages:
/// - Auth state subscription (login/logout)
/// - Live user document subscription at `users/{uid}`
/// - Creating an initial user doc on first login
/// - Profile read/write helpers + onboarding completion
/// - Points update, sign-out, delete account
class UserProvider with ChangeNotifier {
  final FirebaseFirestore _db;
  final AuthService _auth;

  UserProvider({
    FirebaseFirestore? db,
    AuthService? auth,
  })  : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? AuthService();

  UserProfile? _profile;
  bool _loading = false;
  String? _error;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userDocSub;

  bool _initialized = false;
  bool _disposed = false;

  // ------------------------
  // Getters
  // ------------------------
  UserProfile? get profile => _profile;
  bool get loading => _loading;
  String? get error => _error;

  bool get isSignedIn => _auth.isSignedIn;
  String? get uid => _auth.uid;
  bool get isProfileComplete => _profile?.isProfileComplete ?? false;

  // ------------------------
  // Lifecycle
  // ------------------------

  /// Call this once after Firebase.initializeApp(), e.g.:
  /// ChangeNotifierProvider(create: (_) => UserProvider()..initialize())
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _bindAuth();
  }

  @override
  void dispose() {
    _disposed = true;
    _authSub?.cancel();
    _userDocSub?.cancel();
    super.dispose();
  }

  // ------------------------
  // Internal bindings
  // ------------------------

  void _bindAuth() {
    _authSub?.cancel();
    _authSub = _auth.authStateChanges.listen((user) async {
      await _bindUser(user);
    });
  }

  Future<void> _bindUser(User? user) async {
    _userDocSub?.cancel();

    if (user == null) {
      _setState(profile: null, loading: false, error: null);
      return;
    }

    final docRef = _db.collection('users').doc(user.uid);

    // Ensure an initial user document exists (idempotent).
    try {
      final snap = await docRef.get();
      if (!snap.exists) {
        final seed = UserProfile(
          uid: user.uid,
          email: user.email,
          displayName: user.displayName,
          photoUrl: user.photoURL,
          disabilityType: DisabilityType.none,
          points: 0,
          isProfileComplete: false,
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
          preferences: UserPreferences.defaults(),
        );
        await docRef.set(seed.toMap(), SetOptions(merge: true));
      }
    } catch (e) {
      _setState(error: 'init-user-doc-failed');
    }

    // Subscribe to live changes on the user document.
    _userDocSub = docRef.snapshots().listen((doc) {
      final data = doc.data();
      if (data == null) {
        _setState(profile: UserProfile.empty(), loading: false, error: null);
        return;
      }
      // Make sure uid is present before parsing
      final map = Map<String, dynamic>.from(data);
      map['uid'] ??= user.uid;

      final prof = UserProfile.fromMap(map);
      _setState(profile: prof, loading: false, error: null);
    }, onError: (e, st) {
      _setState(error: 'user-doc-listen-failed', loading: false);
    });
  }

  void _setState({UserProfile? profile, bool? loading, String? error}) {
    if (_disposed) return;
    if (profile != null) _profile = profile;
    if (loading != null) _loading = loading;
    _error = error;
    notifyListeners();
  }

  // ------------------------
  // Public actions
  // ------------------------

  /// Force-refresh from Firestore (not usually needed because of live subscription).
  Future<void> refresh() async {
    final id = uid;
    if (id == null) return;
    try {
      _setState(loading: true);
      final snap = await _db.collection('users').doc(id).get();
      _setState(profile: UserProfile.fromMap(snap.data()), loading: false);
    } catch (_) {
      _setState(loading: false, error: 'refresh-failed');
    }
  }

  /// Save full profile (merge by default). The live listener will update local state.
  Future<void> saveProfile(UserProfile newProfile, {bool merge = true}) async {
    final id = uid;
    if (id == null) throw const AuthException('no-user', 'No signed-in user.');
    try {
      final updated = newProfile.touch();
      await _db
          .collection('users')
          .doc(id)
          .set(updated.toMap(), SetOptions(merge: merge));
    } catch (e) {
      _setState(error: 'save-failed');
      rethrow;
    }
  }

  /// Update only preferences.
  Future<void> updatePreferences(UserPreferences prefs) async {
    if (_profile == null) return;
    final p = _profile!.copyWith(preferences: prefs).touch();
    await saveProfile(p);
  }

  /// Mark onboarding (personal settings) as completed.
  Future<void> markOnboardingComplete({
    UserPreferences? prefs,
    DisabilityType? disabilityType,
  }) async {
    if (_profile == null) return;
    var p = _profile!.copyWith(isProfileComplete: true);
    if (prefs != null) p = p.copyWith(preferences: prefs);
    if (disabilityType != null) p = p.copyWith(disabilityType: disabilityType);
    await saveProfile(p);
  }

  /// Atomically add/subtract points.
  Future<void> incrementPoints(int delta) async {
    final id = uid;
    if (id == null) throw const AuthException('no-user', 'No signed-in user.');
    try {
      await _db.runTransaction((tx) async {
        final ref = _db.collection('users').doc(id);
        final snap = await tx.get(ref);
        final data = (snap.data() ?? {}) as Map<String, dynamic>;
        final current = (data['points'] is int)
            ? data['points'] as int
            : int.tryParse('${data['points']}') ?? 0;
        final next = current + delta;
        tx.set(
          ref,
          {
            'points': next,
            'updatedAt': DateTime.now().toUtc().toIso8601String(),
          },
          SetOptions(merge: true),
        );
      });
    } catch (e) {
      _setState(error: 'points-update-failed');
      rethrow;
    }
  }

  /// Sign out (Auth listener will clear local state).
  Future<void> signOut() => _auth.signOut();

  /// Delete account and try to remove Firestore user doc.
  Future<void> deleteAccount() async {
    final u = _auth.currentUser;
    if (u == null) throw const AuthException('no-user', 'No signed-in user.');
    final id = u.uid;

    await _auth.deleteAccount();
    try {
      await _db.collection('users').doc(id).delete();
    } catch (_) {
      // It's fine if the doc is already gone or deletion fails.
    }
  }
}

