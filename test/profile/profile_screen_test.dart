import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:optimeal/core/connectivity/sync_status.dart';
import 'package:optimeal/features/notification/application/notification_providers.dart';
import 'package:optimeal/features/profile/application/logout.dart';
import 'package:optimeal/features/profile/application/profile_providers.dart';
import 'package:optimeal/features/profile/data/profile_repository.dart';
import 'package:optimeal/features/profile/presentation/profile_screen.dart';

class _SpyProfileRepository extends MemoryProfileRepository {
  _SpyProfileRepository(super.initial);

  final List<bool> savedNotificationStates = [];

  @override
  Future<void> setNotificationsEnabled({
    required String uid,
    required bool enabled,
  }) async {
    savedNotificationStates.add(enabled);
    await super.setNotificationsEnabled(uid: uid, enabled: enabled);
  }
}

void main() {
  Future<ProviderContainer> pumpProfile(
    WidgetTester tester, {
    VoidCallback? onLogout,
    ProfileRepository? repo,
    bool writeBlocked = false,
  }) async {
    await tester.binding.setSurfaceSize(const Size(402, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          if (repo != null) profileRepositoryProvider.overrideWithValue(repo),
          if (repo == null)
            profileUserProvider.overrideWithValue(
              const ProfileUser(
                uid: 'u1',
                name: 'Sarah',
                email: 'sarah123@gmail.com',
              ),
            ),
          writeBlockedProvider.overrideWithValue(writeBlocked),
          logoutProvider.overrideWithValue(() async {
            onLogout?.call();
          }),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(ProfileScreen)));
  }

  testWidgets('shows the Figma profile hub', (tester) async {
    await pumpProfile(tester);

    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Sarah'), findsOneWidget);
    expect(find.text('sarah123@gmail.com'), findsOneWidget);
    expect(find.text('S'), findsOneWidget); // initials fallback
    for (final label in [
      'Profile Details',
      'Password',
      'Notifications',
      'Support',
      'About',
      'Logout',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(
      find.byKey(const Key('profile-notifications-switch')),
      findsOneWidget,
    );
  });

  testWidgets('does not offer Dark Mode or Language (PRD v1.11)', (
    tester,
  ) async {
    await pumpProfile(tester);

    expect(find.text('Dark Mode'), findsNothing);
    expect(find.text('Language'), findsNothing);
  });

  testWidgets('tapping Notifications turns reminders on and off', (
    tester,
  ) async {
    final repo = _SpyProfileRepository(
      const ProfileUser(
        uid: 'u1',
        name: 'Sarah',
        email: 'sarah123@gmail.com',
        notificationsEnabled: true,
      ),
    );
    final container = await pumpProfile(tester, repo: repo);

    expect(container.read(notificationSettingsProvider).enabled, isTrue);

    await tester.tap(find.text('Notifications'));
    await tester.pumpAndSettle();

    expect(container.read(notificationSettingsProvider).enabled, isFalse);
    expect(repo.savedNotificationStates, [false]);

    await tester.tap(find.text('Notifications'));
    await tester.pumpAndSettle();

    expect(container.read(notificationSettingsProvider).enabled, isTrue);
    expect(repo.savedNotificationStates, [false, true]);
  });

  testWidgets('blocks notification toggle while offline', (tester) async {
    final repo = _SpyProfileRepository(
      const ProfileUser(
        uid: 'u1',
        name: 'Sarah',
        email: 'sarah123@gmail.com',
        notificationsEnabled: true,
      ),
    );
    final container = await pumpProfile(
      tester,
      repo: repo,
      writeBlocked: true,
    );

    expect(
      find.text('Changing notification settings needs an internet connection.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Notifications'));
    await tester.pumpAndSettle();

    expect(container.read(notificationSettingsProvider).enabled, isTrue);
    expect(repo.savedNotificationStates, isEmpty);
  });

  testWidgets('logout runs the session logout action', (tester) async {
    var loggedOut = false;
    await pumpProfile(tester, onLogout: () => loggedOut = true);

    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();

    expect(loggedOut, isTrue);
  });
}
