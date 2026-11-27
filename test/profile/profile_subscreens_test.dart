import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:optimeal/core/connectivity/sync_status.dart';
import 'package:optimeal/features/auth/application/auth_providers.dart';
import 'package:optimeal/features/auth/data/auth_repository.dart';
import 'package:optimeal/features/profile/application/logout.dart';
import 'package:optimeal/features/profile/application/profile_providers.dart';
import 'package:optimeal/features/profile/data/external_url_launcher.dart';
import 'package:optimeal/features/profile/data/profile_repository.dart';
import 'package:optimeal/features/profile/presentation/about_screen.dart';
import 'package:optimeal/features/profile/presentation/change_password_screen.dart';
import 'package:optimeal/features/profile/presentation/profile_details_screen.dart';
import 'package:optimeal/features/profile/presentation/profile_screen.dart';
import 'package:optimeal/features/profile/presentation/support_screen.dart';

class _FakeAuthRepository implements AuthRepository {
  String? lastNewPassword;
  String? lastCurrentPassword;
  bool requireRecentLoginOnce = false;

  @override
  Future<void> changePassword({
    required String newPassword,
    String? currentPassword,
  }) async {
    if (requireRecentLoginOnce && currentPassword == null) {
      requireRecentLoginOnce = false;
      throw AuthFailure.fromCode('requires-recent-login');
    }
    lastNewPassword = newPassword;
    lastCurrentPassword = currentPassword;
  }

  @override
  Future<void> updateDisplayName(String name) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SpyProfileRepository extends MemoryProfileRepository {
  _SpyProfileRepository(super.initial);

  String? savedDisplayName;
  String? savedFullName;
  String? savedCountryCode;
  String? savedPhone;

  @override
  Future<void> saveDetails({
    required String uid,
    required String email,
    required String displayName,
    String? fullName,
    required String phoneCountryCode,
    String? phoneNumber,
  }) async {
    savedDisplayName = displayName;
    savedFullName = fullName;
    savedCountryCode = phoneCountryCode;
    savedPhone = phoneNumber;
    await super.saveDetails(
      uid: uid,
      email: email,
      displayName: displayName,
      fullName: fullName,
      phoneCountryCode: phoneCountryCode,
      phoneNumber: phoneNumber,
    );
  }
}

void main() {
  Future<void> pumpWithScope(
    WidgetTester tester,
    Widget child, {
    List overrides = const [],
  }) async {
    await tester.binding.setSurfaceSize(const Size(402, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides.cast(),
        child: MaterialApp(home: child),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('navigates from Profile Hub to each sub-screen', (tester) async {
    await pumpWithScope(
      tester,
      const ProfileScreen(),
      overrides: [writeBlockedProvider.overrideWithValue(false)],
    );

    await tester.tap(find.text('Profile Details'));
    await tester.pumpAndSettle();
    expect(find.text('Display Name'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Password'));
    await tester.pumpAndSettle();
    expect(find.text('Change Your Password'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Support'));
    await tester.pumpAndSettle();
    expect(find.text('How can we help?'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('About'));
    await tester.pumpAndSettle();
    expect(find.text('Smart Food Management, Zero Food Waste'), findsOneWidget);
  });

  testWidgets('Profile Details saves edits and triggers Logout', (
    tester,
  ) async {
    final repo = _SpyProfileRepository(
      const ProfileUser(
        uid: 'u1',
        name: 'Sarah',
        fullName: 'Sarah Amalia',
        email: 'sarah123@gmail.com',
        phoneCountryCode: '+62',
        phoneNumber: '81234567812',
      ),
    );
    var loggedOut = false;

    await pumpWithScope(
      tester,
      const ProfileDetailsScreen(),
      overrides: [
        profileRepositoryProvider.overrideWithValue(repo),
        writeBlockedProvider.overrideWithValue(false),
        logoutProvider.overrideWithValue(() async {
          loggedOut = true;
        }),
      ],
    );

    expect(find.text('Display Name'), findsOneWidget);
    expect(find.text('Full Name'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Telephone'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'Nadine');
    await tester.enterText(find.byType(TextFormField).at(1), 'Nadine Putri');
    await tester.enterText(find.byType(TextFormField).at(3), '81122334455');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(repo.savedDisplayName, 'Nadine');
    expect(repo.savedFullName, 'Nadine Putri');
    expect(repo.savedCountryCode, '+62');
    expect(repo.savedPhone, '81122334455');
    expect(find.text('Profile details saved.'), findsOneWidget);

    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();
    expect(loggedOut, isTrue);
  });

  testWidgets('Profile Details disables saving while offline', (tester) async {
    final repo = _SpyProfileRepository(
      const ProfileUser(
        uid: 'u1',
        name: 'Sarah',
        email: 'sarah123@gmail.com',
      ),
    );

    await pumpWithScope(
      tester,
      const ProfileDetailsScreen(),
      overrides: [
        profileRepositoryProvider.overrideWithValue(repo),
        writeBlockedProvider.overrideWithValue(true),
      ],
    );
    expect(
      find.text('Saving profile details needs an internet connection.'),
      findsOneWidget,
    );
  });

  testWidgets('Change Password validates rules and handles recent login', (
    tester,
  ) async {
    final authRepo = _FakeAuthRepository()..requireRecentLoginOnce = true;

    await pumpWithScope(
      tester,
      const ChangePasswordScreen(),
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepo),
        writeBlockedProvider.overrideWithValue(false),
      ],
    );

    expect(find.text('Change Your Password'), findsOneWidget);
    expect(find.text('Minimum 8 characters'), findsOneWidget);
    expect(
      find.text('Include at least one uppercase letter (A-Z)'),
      findsOneWidget,
    );
    expect(find.text('Include at least one number (0-9)'), findsOneWidget);

    // Missing uppercase triggers validation error.
    await tester.enterText(find.byType(TextFormField).at(0), 'optimeal1');
    await tester.enterText(find.byType(TextFormField).at(1), 'optimeal1');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pump();
    expect(
      find.text('Include at least one uppercase letter (A-Z).'),
      findsOneWidget,
    );

    // Valid password triggers recent-login dialog, then succeeds.
    await tester.enterText(find.byType(TextFormField).at(0), 'Optimeal1');
    await tester.enterText(find.byType(TextFormField).at(1), 'Optimeal1');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Confirm current password'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).last, 'OldPass1');
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    expect(authRepo.lastNewPassword, 'Optimeal1');
    expect(authRepo.lastCurrentPassword, 'OldPass1');
  });

  testWidgets('Support opens the Instagram URL on Contact support tap', (
    tester,
  ) async {
    String? openedUrl;

    await pumpWithScope(
      tester,
      const SupportScreen(),
      overrides: [
        externalUrlLauncherProvider.overrideWithValue((url) async {
          openedUrl = url;
          return true;
        }),
      ],
    );

    expect(find.text('How can we help?'), findsOneWidget);
    expect(find.text('Still need a hand?'), findsOneWidget);
    expect(find.text('Contact support'), findsOneWidget);

    await tester.tap(find.text('Contact support'));
    await tester.pumpAndSettle();

    expect(
      openedUrl,
      'https://www.instagram.com/optimeal.hihu?fqnt=c2J4bmIxYmZhNm9n',
    );
  });

  testWidgets('About displays Optimeal overview and feature bullets', (
    tester,
  ) async {
    await pumpWithScope(tester, const AboutScreen());

    expect(find.text('Optimeal'), findsOneWidget);
    expect(find.text('Smart Food Management, Zero Food Waste'), findsOneWidget);
    expect(find.text('About Optimeal'), findsOneWidget);
    expect(find.text('Features'), findsOneWidget);
    expect(
      find.textContaining('Smart Inventory Tracking'),
      findsOneWidget,
    );
    expect(
      find.textContaining('AI Shelf-Life Prediction'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Zero-Waste Recipe Generator'),
      findsOneWidget,
    );
  });
}
