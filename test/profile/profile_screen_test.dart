import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:optimeal/features/profile/application/logout.dart';
import 'package:optimeal/features/profile/application/profile_providers.dart';
import 'package:optimeal/features/profile/presentation/profile_screen.dart';

void main() {
  Future<void> pumpProfile(
    WidgetTester tester, {
    VoidCallback? onLogout,
  }) async {
    await tester.binding.setSurfaceSize(const Size(402, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileUserProvider.overrideWithValue(
            const ProfileUser(
              uid: 'u1',
              name: 'Sarah',
              email: 'sarah123@gmail.com',
            ),
          ),
          logoutProvider.overrideWithValue(() async {
            onLogout?.call();
          }),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();
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
  });

  testWidgets('does not offer Dark Mode or Language (PRD v1.11)', (
    tester,
  ) async {
    await pumpProfile(tester);

    expect(find.text('Dark Mode'), findsNothing);
    expect(find.text('Language'), findsNothing);
  });

  testWidgets('logout runs the session logout action', (tester) async {
    var loggedOut = false;
    await pumpProfile(tester, onLogout: () => loggedOut = true);

    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();

    expect(loggedOut, isTrue);
  });
}
