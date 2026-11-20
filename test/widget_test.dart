import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('smoke test renders Optimeal label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('Optimeal'))),
      ),
    );

    expect(find.text('Optimeal'), findsOneWidget);
  });
}
