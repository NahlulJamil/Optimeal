import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:optimeal/features/auth/presentation/register_screen.dart';

void main() {
  Future<void> pumpRegister(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(402, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: RegisterScreen())),
    );
    await tester.pump();
  }

  Future<void> fillValidForm(WidgetTester tester) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Sarah Putri');
    await tester.enterText(fields.at(1), 'sarah.putri@example.com');
    await tester.enterText(fields.at(2), 'optimeal1');
    await tester.enterText(fields.at(3), 'optimeal1');
  }

  testWidgets('shows every Figma field and the terms checkbox', (
    tester,
  ) async {
    await pumpRegister(tester);

    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget);
    expect(find.textContaining('I agree to Optimeal'), findsOneWidget);
    expect(
      find.text(
        'Use at least 8 characters, including a letter and a number.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('blocks registration until the terms are accepted', (
    tester,
  ) async {
    await pumpRegister(tester);
    await fillValidForm(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pump();

    expect(
      find.text('Please accept the Terms & Conditions to continue.'),
      findsOneWidget,
    );
    // Tidak ada panggilan Firebase: tidak muncul banner error umum.
    expect(find.textContaining('Something went wrong'), findsNothing);
  });

  testWidgets('accepting the terms clears the warning', (tester) async {
    await pumpRegister(tester);
    await fillValidForm(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pump();
    expect(
      find.text('Please accept the Terms & Conditions to continue.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('terms-checkbox')));
    await tester.pump();

    expect(
      find.text('Please accept the Terms & Conditions to continue.'),
      findsNothing,
    );
  });
}
