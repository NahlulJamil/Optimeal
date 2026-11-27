import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optimeal/features/notification/data/notification_service.dart';
import 'package:optimeal/features/notification/domain/notification_planner.dart';

/// Keeps the scheduled ids in memory; scheduling takes one async turn, like
/// the platform channel.
class _FakePlugin implements FlutterLocalNotificationsPlugin {
  final scheduled = <int>[];
  bool failScheduling = false;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    switch (invocation.memberName) {
      case #initialize:
        return Future<bool?>.value(true);
      case #resolvePlatformSpecificImplementation:
        return null;
      case #cancelAll || #cancelAllPendingNotifications:
        scheduled.clear();
        return Future<void>.value();
      case #zonedSchedule:
        final id = invocation.namedArguments[#id] as int;
        return Future<void>.delayed(Duration.zero, () {
          if (failScheduling) throw StateError('schedule failed');
          scheduled.add(id);
        });
    }
    return super.noSuchMethod(invocation);
  }
}

void main() {
  final plan = [
    for (var id = 1; id <= 3; id++)
      PlannedNotification(
        id: id,
        foodId: 'f_$id',
        title: 'Approaching shelf-life estimate',
        body: 'Cook it soon.',
        scheduledAt: DateTime(2030, 1, id, 9),
      ),
  ];

  test('cancelAll is not undone by a schedule still in progress', () async {
    final plugin = _FakePlugin();
    final service = LocalNotificationService(plugin: plugin);

    final scheduling = service.replaceAll(plan, const NotificationSettings());
    final cancelling = service.cancelAll();
    await Future.wait([scheduling, cancelling]);

    expect(plugin.scheduled, isEmpty);
  });

  test('a failed schedule does not block the next change', () async {
    final plugin = _FakePlugin()..failScheduling = true;
    final service = LocalNotificationService(plugin: plugin);

    await expectLater(
      service.replaceAll(plan, const NotificationSettings()),
      throwsStateError,
    );
    plugin.failScheduling = false;
    await service.replaceAll(plan, const NotificationSettings());
    expect(plugin.scheduled, [1, 2, 3]);

    await service.cancelAll();
    expect(plugin.scheduled, isEmpty);
  });
}
