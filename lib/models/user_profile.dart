// lib/models/user_profile.dart
import 'package:flutter/foundation.dart';

/// Disability categories supported by the app.
/// Extend this enum as your product grows.
enum DisabilityType {
  none,
  wheelchair,     // Mobility impairment (wheelchair users)
  visual,         // Visual impairment
  hearing,        // Hearing impairment
  cognitive,      // Cognitive/Intellectual disabilities
  other,
}

/// How the user prefers to sort places.
/// The app can interpret this order to build a weighted scoring later.
enum SortKey {
  personalized,   // ML/CF or personalized feed (future use)
  rating,         // Community rating
  distance,       // Nearest first
  accessibility,  // Accessibility score (ramp, restroom, elevator, etc.)
}

/// A simple wrapper for onboarding and UI preferences.
/// Add more fields as needed (e.g., language, push settings).
@immutable
class UserPreferences {
  /// Primary → Secondary → Tertiary priorities for list sorting.
  final List<SortKey> sortPriorityOrder;

  /// Example toggles for accessibility filters in list views.
  final bool filterWheelchairRamp;
  final bool filterAccessibleRestroom;
  final bool filterElevator;
  final bool filterBrailleMenu;
  final bool filterGuideDogFriendly;

  const UserPreferences({
    required this.sortPriorityOrder,
    this.filterWheelchairRamp = false,
    this.filterAccessibleRestroom = false,
    this.filterElevator = false,
    this.filterBrailleMenu = false,
    this.filterGuideDogFriendly = false,
  });

  /// Default preferences used at first launch or for anonymous users.
  factory UserPreferences.defaults() => const UserPreferences(
        sortPriorityOrder: [SortKey.personalized, SortKey.rating, SortKey.distance],
      );

  UserPreferences copyWith({
    List<SortKey>? sortPriorityOrder,
    bool? filterWheelchairRamp,
    bool? filterAccessibleRestroom,
    bool? filterElevator,
    bool? filterBrailleMenu,
    bool? filterGuideDogFriendly,
  }) {
    return UserPreferences(
      sortPriorityOrder: sortPriorityOrder ?? this.sortPriorityOrder,
      filterWheelchairRamp: filterWheelchairRamp ?? this.filterWheelchairRamp,
      filterAccessibleRestroom:
          filterAccessibleRestroom ?? this.filterAccessibleRestroom,
      filterElevator: filterElevator ?? this.filterElevator,
      filterBrailleMenu: filterBrailleMenu ?? this.filterBrailleMenu,
      filterGuideDogFriendly:
          filterGuideDogFriendly ?? this.filterGuideDogFriendly,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sortPriorityOrder': sortPriorityOrder.map((e) => e.name).toList(),
      'filterWheelchairRamp': filterWheelchairRamp,
      'filterAccessibleRestroom': filterAccessibleRestroom,
      'filterElevator': filterElevator,
      'filterBrailleMenu': filterBrailleMenu,
      'filterGuideDogFriendly': filterGuideDogFriendly,
    };
  }

  factory UserPreferences.fromMap(Map<String, dynamic>? map) {
    if (map == null) return UserPreferences.defaults();

    List<dynamic>? rawOrder = map['sortPriorityOrder'] as List<dynamic>?;
    final order = (rawOrder ?? const <dynamic>[])
        .map((e) => _sortKeyFrom(e))
        .whereType<SortKey>()
        .toList();

    return UserPreferences(
      sortPriorityOrder: order.isEmpty
          ? UserPreferences.defaults().sortPriorityOrder
          : order,
      filterWheelchairRamp: (map['filterWheelchairRamp'] as bool?) ?? false,
      filterAccessibleRestroom:
          (map['filterAccessibleRestroom'] as bool?) ?? false,
      filterElevator: (map['filterElevator'] as bool?) ?? false,
      filterBrailleMenu: (map['filterBrailleMenu'] as bool?) ?? false,
      filterGuideDogFriendly:
          (map['filterGuideDogFriendly'] as bool?) ?? false,
    );
  }

  static SortKey? _sortKeyFrom(dynamic value) {
    if (value == null) return null;
    try {
      final name = value.toString();
      return SortKey.values.firstWhere((e) => e.name == name);
    } catch (_) {
      return null;
    }
  }

  @override
  String toString() => 'UserPreferences(${toMap()})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserPreferences &&
          listEquals(other.sortPriorityOrder, sortPriorityOrder) &&
          other.filterWheelchairRamp == filterWheelchairRamp &&
          other.filterAccessibleRestroom == filterAccessibleRestroom &&
          other.filterElevator == filterElevator &&
          other.filterBrailleMenu == filterBrailleMenu &&
          other.filterGuideDogFriendly == filterGuideDogFriendly;

  @override
  int get hashCode => Object.hash(
        Object.hashAll(sortPriorityOrder),
        filterWheelchairRamp,
        filterAccessibleRestroom,
        filterElevator,
        filterBrailleMenu,
        filterGuideDogFriendly,
      );
}

/// Core user profile stored in Firestore under `users/{uid}`.
/// Keep this model *package-agnostic*: do not import firebase packages here.
/// Timestamp from Firestore is handled via `_toDateTime`.
@immutable
class UserProfile {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;

  final DisabilityType disabilityType;

  /// Points or badges for participation (e.g., reviews, verifications).
  final int points;

  /// Whether onboarding (personal settings) is fully completed.
  final bool isProfileComplete;

  /// Creation & update timestamps (UTC).
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Preferences for sorting, filtering, etc.
  final UserPreferences preferences;

  const UserProfile({
    required this.uid,
    this.email,
    this.displayName,
    this.photoUrl,
    this.disabilityType = DisabilityType.none,
    this.points = 0,
    this.isProfileComplete = false,
    this.createdAt,
    this.updatedAt,
    required this.preferences,
  });

  /// Empty/anonymous placeholder used before login or when data is missing.
  factory UserProfile.empty() => UserProfile(
        uid: 'anonymous',
        email: null,
        displayName: null,
        photoUrl: null,
        disabilityType: DisabilityType.none,
        points: 0,
        isProfileComplete: false,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
        preferences: UserPreferences.defaults(),
      );

  UserProfile copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoUrl,
    DisabilityType? disabilityType,
    int? points,
    bool? isProfileComplete,
    DateTime? createdAt,
    DateTime? updatedAt,
    UserPreferences? preferences,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      disabilityType: disabilityType ?? this.disabilityType,
      points: points ?? this.points,
      isProfileComplete: isProfileComplete ?? this.isProfileComplete,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      preferences: preferences ?? this.preferences,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'disabilityType': disabilityType.name,
      'points': points,
      'isProfileComplete': isProfileComplete,
      // Store as ISO-8601 string; Firestore can store Date/Timestamp directly via client layer.
      'createdAt': createdAt?.toUtc().toIso8601String(),
      'updatedAt': updatedAt?.toUtc().toIso8601String(),
      'preferences': preferences.toMap(),
    };
  }

  /// Build from a Firestore map or any JSON-like structure.
  /// It gracefully handles Google's `Timestamp` type by reading `toDate()` if available.
  factory UserProfile.fromMap(Map<String, dynamic>? map) {
    if (map == null) return UserProfile.empty();

    // Parse disability enum
    final disabilityRaw = map['disabilityType']?.toString();
    final disability = DisabilityType.values.firstWhere(
      (e) => e.name == disabilityRaw,
      orElse: () => DisabilityType.none,
    );

    return UserProfile(
      uid: (map['uid'] ?? '').toString(),
      email: _toNullableString(map['email']),
      displayName: _toNullableString(map['displayName']),
      photoUrl: _toNullableString(map['photoUrl']),
      disabilityType: disability,
      points: _toInt(map['points'], defaultValue: 0),
      isProfileComplete: (map['isProfileComplete'] as bool?) ?? false,
      createdAt: _toDateTime(map['createdAt']),
      updatedAt: _toDateTime(map['updatedAt']),
      preferences: UserPreferences.fromMap(
        (map['preferences'] as Map?)?.cast<String, dynamic>(),
      ),
    );
  }

  /// Convenience to update `updatedAt` to now (UTC).
  UserProfile touch() => copyWith(updatedAt: DateTime.now().toUtc());

  /// Whether minimum info for using the app is present.
  /// Adjust this rule to your product requirement.
  bool get hasMinimumProfile =>
      uid.isNotEmpty && (email != null || displayName != null);

  @override
  String toString() => 'UserProfile(${toMap()})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile &&
          other.uid == uid &&
          other.email == email &&
          other.displayName == displayName &&
          other.photoUrl == photoUrl &&
          other.disabilityType == disabilityType &&
          other.points == points &&
          other.isProfileComplete == isProfileComplete &&
          other.createdAt == createdAt &&
          other.updatedAt == updatedAt &&
          other.preferences == preferences;

  @override
  int get hashCode => Object.hash(
        uid,
        email,
        displayName,
        photoUrl,
        disabilityType,
        points,
        isProfileComplete,
        createdAt,
        updatedAt,
        preferences,
      );

  // ------------------------
  // Helpers (parsers)
  // ------------------------

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;

    // Firestore Timestamp?
    // We avoid importing firebase types here: duck-typing `toDate()` if exists.
    try {
      // Most Timestamp-like objects have a toDate() -> DateTime
      final toDate = value.toDate;
      if (toDate is Function) {
        final dt = toDate();
        if (dt is DateTime) return dt.toUtc();
      }
    } catch (_) {
      // ignore
    }

    // ISO-8601 string?
    if (value is String) {
      return DateTime.tryParse(value)?.toUtc();
    }

    // Milliseconds since epoch?
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    }

    return null;
  }

  static int _toInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    final s = value.toString();
    return int.tryParse(s) ?? defaultValue;
  }

  static String? _toNullableString(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    return s.isEmpty ? null : s;
  }
}

