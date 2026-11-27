import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/connectivity/online_status.dart';
import '../../auth/application/auth_providers.dart';
import '../../notification/application/notification_providers.dart';
import '../data/profile_repository.dart';

export '../data/profile_repository.dart' show ProfileUser;

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  if (AppConfig.useMock) {
    return MemoryProfileRepository(
      const ProfileUser(
        uid: 'mock-user',
        name: 'Sarah',
        fullName: 'Sarah Amalia',
        email: 'sarah123@gmail.com',
        phoneCountryCode: '+62',
        phoneNumber: '81234567812',
      ),
    );
  }
  return FirestoreProfileRepository();
});

/// Loads and updates the signed-in user's profile (`users/{uid}`) and keeps
/// [notificationSettingsProvider] aligned with the saved preferences.
class ProfileController extends AsyncNotifier<ProfileUser?> {
  ProfileRepository get _repo => ref.read(profileRepositoryProvider);

  @override
  Future<ProfileUser?> build() async {
    ref.watch(profileRepositoryProvider);
    final fallback = _authFallback();
    if (fallback == null) return null;

    final online = ref.read(onlineStatusProvider);
    try {
      final loaded = await _repo.fetch(
        fallback: fallback,
        fromCache: !online,
      );
      _syncNotificationSettings(loaded);
      return loaded;
    } on Object {
      _syncNotificationSettings(fallback);
      return fallback;
    }
  }

  ProfileUser? _authFallback() {
    if (AppConfig.useMock) {
      return const ProfileUser(
        uid: 'mock-user',
        name: 'Sarah',
        fullName: 'Sarah Amalia',
        email: 'sarah123@gmail.com',
        phoneCountryCode: '+62',
        phoneNumber: '81234567812',
      );
    }
    final user = ref.watch(authStateProvider).value;
    if (user == null) return null;
    final displayName = user.displayName?.trim();
    return ProfileUser(
      uid: user.uid,
      name: (displayName == null || displayName.isEmpty)
          ? _nameFromEmail(user.email)
          : displayName,
      email: user.email ?? '',
      photoUrl: user.photoURL,
    );
  }

  void _syncNotificationSettings(ProfileUser profile) {
    final notifier = ref.read(notificationSettingsProvider.notifier);
    notifier.setEnabled(profile.notificationsEnabled);
    notifier.setThresholdDays(profile.notificationThresholdDays);
  }

  /// Toggles notifications on/off and persists `notificationsEnabled` to
  /// `users/{uid}` (PRD §3.6, §3.7).
  Future<void> setNotificationsEnabled(bool enabled) async {
    final current = state.value;
    if (current == null) return;
    final previous = current.notificationsEnabled;

    // Optimistic update so the switch and NotificationSync react right away.
    final updated = current.copyWith(notificationsEnabled: enabled);
    state = AsyncData(updated);
    ref.read(notificationSettingsProvider.notifier).setEnabled(enabled);

    try {
      await _repo.setNotificationsEnabled(uid: current.uid, enabled: enabled);
    } catch (_) {
      state = AsyncData(current.copyWith(notificationsEnabled: previous));
      ref.read(notificationSettingsProvider.notifier).setEnabled(previous);
      rethrow;
    }
  }

  /// Saves Profile Details (`Display Name`, `Full Name`, `Telephone`) to
  /// Firestore and updates FirebaseAuth's `displayName`.
  Future<void> saveDetails({
    required String displayName,
    String? fullName,
    required String phoneCountryCode,
    String? phoneNumber,
  }) async {
    final current = state.value;
    if (current == null) return;
    final trimmedDisplay = displayName.trim();
    final trimmedFull = fullName?.trim();
    final trimmedPhone = phoneNumber?.trim();

    await _repo.saveDetails(
      uid: current.uid,
      email: current.email,
      displayName: trimmedDisplay,
      fullName: trimmedFull,
      phoneCountryCode: phoneCountryCode,
      phoneNumber: trimmedPhone,
    );

    if (!AppConfig.useMock) {
      await ref.read(authRepositoryProvider).updateDisplayName(trimmedDisplay);
      ref.invalidate(authStateProvider);
    }

    state = AsyncData(
      current.copyWith(
        name: trimmedDisplay,
        fullName: (trimmedFull == null || trimmedFull.isEmpty)
            ? null
            : trimmedFull,
        phoneCountryCode: phoneCountryCode,
        phoneNumber: (trimmedPhone == null || trimmedPhone.isEmpty)
            ? null
            : trimmedPhone,
      ),
    );
  }
}

final profileControllerProvider =
    AsyncNotifierProvider<ProfileController, ProfileUser?>(
      ProfileController.new,
    );

/// Synchronous profile view used by the Profile Hub, Profile Details, and Home.
///
/// Falls back to FirebaseAuth's user while [profileControllerProvider] is
/// loading so the header renders immediately without a flicker.
final profileUserProvider = Provider<ProfileUser?>((ref) {
  final loaded = ref.watch(profileControllerProvider).value;
  if (loaded != null) return loaded;
  if (AppConfig.useMock) {
    return const ProfileUser(
      uid: 'mock-user',
      name: 'Sarah',
      fullName: 'Sarah Amalia',
      email: 'sarah123@gmail.com',
      phoneCountryCode: '+62',
      phoneNumber: '81234567812',
    );
  }
  final user = ref.watch(authStateProvider).value;
  if (user == null) return null;
  final displayName = user.displayName?.trim();
  return ProfileUser(
    uid: user.uid,
    name: (displayName == null || displayName.isEmpty)
        ? _nameFromEmail(user.email)
        : displayName,
    email: user.email ?? '',
    photoUrl: user.photoURL,
  );
});

String _nameFromEmail(String? email) {
  final local = (email ?? '').split('@').first.trim();
  if (local.isEmpty) return 'Optimeal user';
  return local[0].toUpperCase() + local.substring(1);
}
