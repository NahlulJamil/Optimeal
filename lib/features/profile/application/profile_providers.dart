import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';

/// Header data for the Profile screen (PRD §3.7: photo, name, email).
class ProfileUser {
  const ProfileUser({
    required this.uid,
    required this.name,
    required this.email,
    this.photoUrl,
  });

  final String uid;
  final String name;
  final String email;

  /// Firebase `photoURL`. Accounts created with email/password have none, so
  /// the header falls back to the name's initials.
  final String? photoUrl;
}

final profileUserProvider = Provider<ProfileUser?>((ref) {
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
