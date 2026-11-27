import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/notification_planner.dart';

/// Schedules the reminders on the device (PRD §2.3 rule 8: local only, no
/// server push, works offline).
abstract class NotificationService {
  /// Food id (or [summaryPayload]) of tapped notifications, for deep links.
  Stream<String> get taps;

  Future<void> init();

  /// Asks for POST_NOTIFICATIONS and, when possible, exact alarms.
  Future<void> requestPermissions();

  /// Replaces every pending reminder with [plan].
  Future<void> replaceAll(
    List<PlannedNotification> plan,
    NotificationSettings settings,
  );

  /// Removes every reminder, pending or already shown (logout, PRD §6.7).
  Future<void> cancelAll();

  /// Payload of the notification that launched the app, if any.
  Future<String?> launchPayload();
}

class LocalNotificationService implements NotificationService {
  LocalNotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const String channelId = 'shelf_life_reminders';

  final FlutterLocalNotificationsPlugin _plugin;
  final _taps = StreamController<String>.broadcast();
  Future<void>? _init;
  Future<void> _queue = Future.value();
  bool _exactAllowed = false;

  @override
  Stream<String> get taps => _taps.stream;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<void> init() => _init ??= _doInit();

  Future<void> _doInit() async {
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) _taps.add(payload);
      },
    );
    _exactAllowed = await _android?.canScheduleExactNotifications() ?? false;
  }

  @override
  Future<void> requestPermissions() async {
    await init();
    final android = _android;
    if (android == null) return;
    await android.requestNotificationsPermission();
    if (!_exactAllowed) {
      _exactAllowed = await android.requestExactAlarmsPermission() ?? false;
    }
  }

  /// Runs schedule changes one at a time, so a [replaceAll] still in progress
  /// cannot add reminders back after a later [cancelAll].
  Future<void> _serialized(Future<void> Function() action) {
    final result = _queue.then((_) => action());
    // A failed change is reported to its caller but must not block the next.
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  @override
  Future<void> cancelAll() => _serialized(() async {
    await init();
    await _plugin.cancelAll();
  });

  @override
  Future<void> replaceAll(
    List<PlannedNotification> plan,
    NotificationSettings settings,
  ) => _serialized(() => _schedule(plan, settings));

  Future<void> _schedule(
    List<PlannedNotification> plan,
    NotificationSettings settings,
  ) async {
    await init();
    // Pending only: reminders already on screen stay visible.
    await _plugin.cancelAllPendingNotifications();
    final copy = NotificationCopy(settings.language);
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        copy.channelName,
        channelDescription: copy.channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    for (final n in plan) {
      await _plugin.zonedSchedule(
        id: n.id,
        // UTC instant of the local reminder time; no device time-zone name
        // is needed for a one-off reminder.
        scheduledDate: tz.TZDateTime.from(n.scheduledAt.toUtc(), tz.UTC),
        notificationDetails: details,
        androidScheduleMode: _exactAllowed
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        title: n.title,
        body: n.body,
        payload: n.foodId,
      );
    }
  }

  @override
  Future<String?> launchPayload() async {
    await init();
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return null;
    return details?.notificationResponse?.payload;
  }
}
