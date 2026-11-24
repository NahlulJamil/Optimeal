import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:optimeal/core/connectivity/sync_status.dart';
import 'package:optimeal/core/widgets/sync_status_line.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.utc(2026, 11, 24, 12);

  Widget app() => ProviderScope(
    child: MaterialApp(
      home: Scaffold(body: Center(child: SyncStatusLine(now: now))),
    ),
  );

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(SyncStatusLine)));

  testWidgets('shows every sync phase', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(app());
    final controller = containerOf(tester).read(syncStatusProvider.notifier);

    controller.markSynced(now.subtract(const Duration(minutes: 5)));
    await tester.pump();
    expect(find.text('Synced 5 min ago'), findsOneWidget);

    controller.markSyncing();
    await tester.pump();
    expect(find.text('Syncing…'), findsOneWidget);

    controller.markOffline();
    await tester.pump();
    expect(find.text('Offline · Last synced 5 min ago'), findsOneWidget);

    controller.markError();
    await tester.pump();
    expect(find.text('Could not sync · Last synced 5 min ago'), findsOneWidget);
  });

  testWidgets('offline without a cached timestamp', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(app());
    containerOf(tester).read(syncStatusProvider.notifier).markOffline();
    await tester.pump();

    expect(find.text('Offline · No cached data yet'), findsOneWidget);
  });
}
