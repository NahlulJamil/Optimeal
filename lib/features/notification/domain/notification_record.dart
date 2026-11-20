import 'notification_planner.dart';

/// Contracts §2.4.
enum NotificationStatus {
  scheduled,
  delivered,
  read,
  cancelled;

  static NotificationStatus? tryParse(Object? value) {
    for (final s in values) {
      if (s.name == value) return s;
    }
    return null;
  }
}

/// History of a reminder, `users/{uid}/notifications/{notificationId}`
/// (PRD §6.4, Contracts §3.4). The reminder itself is shown by the device;
/// this record only keeps track of it.
class NotificationRecord {
  const NotificationRecord({
    required this.notificationId,
    required this.userId,
    required this.foodId,
    required this.title,
    required this.body,
    required this.scheduledAt,
    required this.status,
  });

  final String notificationId;
  final String userId;

  /// Food id, or `"summary"` for the summary reminder.
  final String foodId;
  final String title;
  final String body;
  final DateTime scheduledAt;
  final NotificationStatus status;

  /// One record per reminder and day: the local id is stable per food and
  /// kind, so the date keeps older reminders as separate history.
  static String idFor(PlannedNotification n) {
    final d = n.scheduledAt;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${n.id}-${d.year}${two(d.month)}${two(d.day)}';
  }

  factory NotificationRecord.scheduled(
    PlannedNotification n, {
    required String userId,
  }) => NotificationRecord(
    notificationId: idFor(n),
    userId: userId,
    foodId: n.foodId,
    title: n.title,
    body: n.body,
    scheduledAt: n.scheduledAt,
    status: NotificationStatus.scheduled,
  );

  bool sameContentAs(NotificationRecord other) =>
      foodId == other.foodId &&
      title == other.title &&
      body == other.body &&
      scheduledAt.isAtSameMomentAs(other.scheduledAt) &&
      status == other.status;
}

/// Writes needed to bring the stored history in line with a new schedule.
class NotificationRecordChanges {
  const NotificationRecordChanges({
    this.upserts = const [],
    this.statusUpdates = const {},
  });

  /// New or changed scheduled reminders.
  final List<NotificationRecord> upserts;

  /// Record id → new status for reminders that left the schedule.
  final Map<String, NotificationStatus> statusUpdates;

  bool get isEmpty => upserts.isEmpty && statusUpdates.isEmpty;
}

/// Compares the stored `scheduled` records with the new [plan]:
/// * planned reminders are written only when new or changed;
/// * a scheduled record that is no longer planned became `delivered` when
///   its time has passed (the planner never schedules the past), otherwise
///   it was `cancelled` (food deleted or edited, or reminders turned off).
NotificationRecordChanges diffNotificationRecords({
  required List<NotificationRecord> storedScheduled,
  required List<PlannedNotification> plan,
  required String userId,
  required DateTime now,
}) {
  final stored = {for (final r in storedScheduled) r.notificationId: r};
  final planned = {
    for (final n in plan)
      NotificationRecord.idFor(n): NotificationRecord.scheduled(
        n,
        userId: userId,
      ),
  };

  final upserts = [
    for (final entry in planned.entries)
      if (!(stored[entry.key]?.sameContentAs(entry.value) ?? false))
        entry.value,
  ];
  final statusUpdates = {
    for (final r in storedScheduled)
      if (!planned.containsKey(r.notificationId))
        r.notificationId: r.scheduledAt.isAfter(now)
            ? NotificationStatus.cancelled
            : NotificationStatus.delivered,
  };
  return NotificationRecordChanges(
    upserts: upserts,
    statusUpdates: statusUpdates,
  );
}

/// Ids of the records to mark `read` after the user taps a reminder for
/// [foodId] (or the summary): those already shown, not yet read.
List<String> recordsToMarkRead(
  List<NotificationRecord> recordsForFood,
  DateTime now,
) => [
  for (final r in recordsForFood)
    if (!r.scheduledAt.isAfter(now) &&
        (r.status == NotificationStatus.delivered ||
            r.status == NotificationStatus.scheduled))
      r.notificationId,
];
