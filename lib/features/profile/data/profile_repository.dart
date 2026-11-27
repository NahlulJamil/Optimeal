import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/connectivity/offline_error.dart';

/// User profile & preferences stored at `users/{uid}` (PRD §3.7, Contracts §3.5).
class ProfileUser {
  const ProfileUser({
    required this.uid,
    required this.name,
    required this.email,
    this.photoUrl,
    this.fullName,
    this.phoneCountryCode = '+62',
    this.phoneNumber,
    this.notificationsEnabled = true,
    this.notificationThresholdDays = 1,
  });

  final String uid;

  /// Display name (also synced to FirebaseAuth `displayName` and Home greeting).
  final String name;
  final String? fullName;
  final String email;

  /// Firebase `photoURL`. Accounts created with email/password have none, so
  /// the header falls back to the name's initials.
  final String? photoUrl;

  final String phoneCountryCode;
  final String? phoneNumber;
  final bool notificationsEnabled;
  final int notificationThresholdDays;

  ProfileUser copyWith({
    String? name,
    Object? fullName = _unset,
    String? email,
    Object? photoUrl = _unset,
    String? phoneCountryCode,
    Object? phoneNumber = _unset,
    bool? notificationsEnabled,
    int? notificationThresholdDays,
  }) => ProfileUser(
    uid: uid,
    name: name ?? this.name,
    fullName: identical(fullName, _unset) ? this.fullName : fullName as String?,
    email: email ?? this.email,
    photoUrl: identical(photoUrl, _unset) ? this.photoUrl : photoUrl as String?,
    phoneCountryCode: phoneCountryCode ?? this.phoneCountryCode,
    phoneNumber: identical(phoneNumber, _unset)
        ? this.phoneNumber
        : phoneNumber as String?,
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    notificationThresholdDays:
        notificationThresholdDays ?? this.notificationThresholdDays,
  );
}

const Object _unset = Object();

abstract class ProfileRepository {
  Future<ProfileUser> fetch({
    required ProfileUser fallback,
    bool fromCache = false,
  });

  Future<void> saveDetails({
    required String uid,
    required String email,
    required String displayName,
    String? fullName,
    required String phoneCountryCode,
    String? phoneNumber,
  });

  Future<void> setNotificationsEnabled({
    required String uid,
    required bool enabled,
  });
}

/// In-memory profile store for mock mode (`USE_MOCK=true`) and tests.
class MemoryProfileRepository implements ProfileRepository {
  MemoryProfileRepository([ProfileUser? initial]) : _stored = initial;

  ProfileUser? _stored;

  @override
  Future<ProfileUser> fetch({
    required ProfileUser fallback,
    bool fromCache = false,
  }) async {
    return _stored ??= fallback;
  }

  @override
  Future<void> saveDetails({
    required String uid,
    required String email,
    required String displayName,
    String? fullName,
    required String phoneCountryCode,
    String? phoneNumber,
  }) async {
    final current =
        _stored ?? ProfileUser(uid: uid, name: displayName, email: email);
    _stored = current.copyWith(
      name: displayName,
      fullName: fullName,
      email: email,
      phoneCountryCode: phoneCountryCode,
      phoneNumber: phoneNumber,
    );
  }

  @override
  Future<void> setNotificationsEnabled({
    required String uid,
    required bool enabled,
  }) async {
    final current = _stored;
    if (current != null) {
      _stored = current.copyWith(notificationsEnabled: enabled);
    }
  }
}

/// Firestore implementation (`users/{uid}`) on Firebase Spark plan.
class FirestoreProfileRepository implements ProfileRepository {
  FirestoreProfileRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('users').doc(uid);

  @override
  Future<ProfileUser> fetch({
    required ProfileUser fallback,
    bool fromCache = false,
  }) async {
    final snapshot = await _readDoc(fallback.uid, fromCache: fromCache);
    final data = snapshot?.data();
    if (data == null) return fallback;

    String? optionalText(String key) {
      final raw = data[key];
      if (raw is! String) return null;
      final trimmed = raw.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    final thresholdRaw = data['notificationThresholdDays'];
    final threshold = thresholdRaw is num
        ? thresholdRaw.toInt().clamp(1, 3)
        : fallback.notificationThresholdDays;

    return ProfileUser(
      uid: fallback.uid,
      name: optionalText('name') ?? fallback.name,
      fullName: optionalText('fullName'),
      email: optionalText('email') ?? fallback.email,
      photoUrl: optionalText('photoUrl') ?? fallback.photoUrl,
      phoneCountryCode: optionalText('phoneCountryCode') ?? '+62',
      phoneNumber: optionalText('phoneNumber'),
      notificationsEnabled:
          data['notificationsEnabled'] as bool? ?? fallback.notificationsEnabled,
      notificationThresholdDays: threshold,
    );
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _readDoc(
    String uid, {
    required bool fromCache,
  }) async {
    final ref = _doc(uid);
    if (fromCache) {
      try {
        return await ref.get(const GetOptions(source: Source.cache));
      } on FirebaseException {
        return null;
      }
    }
    try {
      return await ref.get(const GetOptions(source: Source.serverAndCache));
    } on FirebaseException catch (error) {
      if (!isOfflineError(error)) rethrow;
      try {
        return await ref.get(const GetOptions(source: Source.cache));
      } on FirebaseException {
        return null;
      }
    }
  }

  @override
  Future<void> saveDetails({
    required String uid,
    required String email,
    required String displayName,
    String? fullName,
    required String phoneCountryCode,
    String? phoneNumber,
  }) {
    return _doc(uid).set({
      'uid': uid,
      'email': email,
      'name': displayName.trim(),
      'fullName': _nullIfEmpty(fullName),
      'phoneCountryCode': phoneCountryCode,
      'phoneNumber': _nullIfEmpty(phoneNumber),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> setNotificationsEnabled({
    required String uid,
    required bool enabled,
  }) {
    return _doc(uid).set({
      'uid': uid,
      'notificationsEnabled': enabled,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static String? _nullIfEmpty(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}
