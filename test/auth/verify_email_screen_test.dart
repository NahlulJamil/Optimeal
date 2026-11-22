import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:optimeal/features/auth/presentation/verify_email_screen.dart';

void main() {
  testWidgets('shows the verification instructions and resend control', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(402, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: VerifyEmailScreen(email: 'sarah.putri@example.com'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Check your inbox!'), findsOneWidget);
    expect(find.textContaining('sarah.putri@example.com'), findsOneWidget);
    expect(find.text('Change email'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, "I've verified my email"),
      findsOneWidget,
    );
    expect(find.text("Didn't get the email?"), findsOneWidget);
    expect(find.text('Send it again'), findsOneWidget);
  });
}
