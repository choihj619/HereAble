// lib/providers/user_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_profile.dart';
import '../services/auth_service.dart';

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

    // 초기 유저 문서 생성 (없을 시)
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
    } catch (_) {
      _setState(error: 'init-user-doc-failed');
    }

    // 실시간 구독
    _userDocSub = docRef.snapshots().listen((doc) {
      final data = doc.data();
      if (data == null) {
        _setState(profile: UserProfile.empty(), loading: false);
        return;
      }
      final map = Map<String, dynamic>.from(data)..['uid'] ??= user.uid;
      _setState(profile: UserProfile.fromMap(map), loading: false);
    }, onError: (_) {
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

  Future<void> saveProfile(UserProfile newProfile, {bool merge = true}) async {
    final id = uid;
    if (id == null) throw const AuthException('no-user', 'No signed-in user.');
    try {
      final updated = newProfile.touch();
      await _db
          .collection('users')
          .doc(id)
          .set(updated.toMap(), SetOptions(merge: merge));
    } catch (_) {
      _setState(error: 'save-failed');
      rethrow;
    }
  }

  Future<void> updatePreferences(UserPreferences prefs) async {
    if (_profile == null) return;
    try {
      final p = _profile!.copyWith(preferences: prefs).touch();
      await saveProfile(p);
    } catch (_) {
      _setState(error: 'update-prefs-failed');
      rethrow;
    }
  }

  /// 온보딩 완료 처리 + Firestore 저장
  Future<void> markOnboardingComplete({
    UserPreferences? prefs,
    DisabilityType? disabilityType,
  }) async {
    if (_profile == null) return;
    try {
      var p = _profile!.copyWith(
        isProfileComplete: true,
        preferences: prefs ?? _profile!.preferences,
        disabilityType: disabilityType ?? _profile!.disabilityType,
      ).touch();

      await saveProfile(p);
    } catch (_) {
      _setState(error: 'onboarding-save-failed');
      rethrow;
    }
  }

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
        tx.set(
          ref,
          {
            'points': current + delta,
            'updatedAt': DateTime.now().toUtc().toIso8601String(),
          },
          SetOptions(merge: true),
        );
      });
    } catch (_) {
      _setState(error: 'points-update-failed');
      rethrow;
    }
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> deleteAccount() async {
    final u = _auth.currentUser;
    if (u == null) throw const AuthException('no-user', 'No signed-in user.');
    final id = u.uid;

    await _auth.deleteAccount();
    try {
      await _db.collection('users').doc(id).delete();
    } catch (_) {
      // 이미 삭제되었거나 실패해도 무방
    }
  }
}
