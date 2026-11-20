import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/notification_planner.dart';
import '../domain/notification_record.dart';

/// Stores reminder history (PRD §6.4). Failures here never affect the
/// reminders themselves, which are scheduled on the device.
abstract class NotificationRecordRepository {
  /// Brings the stored history in line with the schedule just set.
  Future<void> syncWithPlan(List<PlannedNotification> plan, DateTime now);

  /// Marks the shown reminders for [foodId] (or `summary`) as read.
  Future<void> markRead(String foodId, DateTime now);
}

/// Mock mode and signed-out state: nothing is stored.
class NoopNotificationRecordRepository implements NotificationRecordRepository {
  const NoopNotificationRecordRepository();

  @override
  Future<void> syncWithPlan(
    List<PlannedNotification> plan,
    DateTime now,
  ) async {}

  @override
  Future<void> markRead(String foodId, DateTime now) async {}
}

class FirestoreNotificationRecordRepository
    implements NotificationRecordRepository {
  FirestoreNotificationRecordRepository({
    required this.userId,
    FirebaseFirestore? firestore,
  }) : _db = firestore ?? FirebaseFirestore.instance;

  final String userId;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _records =>
      _db.collection('users').doc(userId).collection('notifications');

  @override
  Future<void> syncWithPlan(
    List<PlannedNotification> plan,
    DateTime now,
  ) async {
    // Single-field filter: no composite index needed.
    final snapshot = await _records
        .where('status', isEqualTo: NotificationStatus.scheduled.name)
        .get();
    final stored = [
      for (final doc in snapshot.docs)
        ?notificationRecordFromFirestore(doc.id, doc.data()),
    ];
    final changes = diffNotificationRecords(
      storedScheduled: stored,
      plan: plan,
      userId: userId,
      now: now,
    );
    if (changes.isEmpty) return;

    // Firestore batches hold at most 500 writes.
    final writes = <void Function(WriteBatch)>[
      for (final r in changes.upserts)
        (b) => b.set(
          _records.doc(r.notificationId),
          notificationRecordToFirestore(r),
        ),
      for (final e in changes.statusUpdates.entries)
        (b) => b.update(_records.doc(e.key), {'status': e.value.name}),
    ];
    for (var i = 0; i < writes.length; i += 450) {
      final batch = _db.batch();
      for (final write in writes.skip(i).take(450)) {
        write(batch);
      }
      await batch.commit();
    }
  }

  @override
  Future<void> markRead(String foodId, DateTime now) async {
    final snapshot = await _records.where('foodId', isEqualTo: foodId).get();
    final records = [
      for (final doc in snapshot.docs)
        ?notificationRecordFromFirestore(doc.id, doc.data()),
    ];
    final ids = recordsToMarkRead(records, now);
    if (ids.isEmpty) return;
    final batch = _db.batch();
    for (final id in ids) {
      batch.update(_records.doc(id), {'status': NotificationStatus.read.name});
    }
    await batch.commit();
  }
}

Map<String, Object?> notificationRecordToFirestore(NotificationRecord r) => {
  'notificationId': r.notificationId,
  'userId': r.userId,
  'foodId': r.foodId,
  'title': r.title,
  'body': r.body,
  'scheduledAt': Timestamp.fromDate(r.scheduledAt),
  'status': r.status.name,
};

NotificationRecord? notificationRecordFromFirestore(
  String id,
  Map<String, dynamic> data,
) {
  final at = data['scheduledAt'];
  final status = NotificationStatus.tryParse(data['status']);
  final foodId = data['foodId'];
  if (at is! Timestamp || status == null || foodId is! String) return null;
  return NotificationRecord(
    notificationId: id,
    userId: data['userId'] as String? ?? '',
    foodId: foodId,
    title: data['title'] as String? ?? '',
    body: data['body'] as String? ?? '',
    scheduledAt: at.toDate(),
    status: status,
  );
}
