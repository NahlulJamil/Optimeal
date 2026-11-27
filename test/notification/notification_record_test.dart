import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optimeal/core/models/food_item.dart';
import 'package:optimeal/features/notification/application/notification_providers.dart';
import 'package:optimeal/features/notification/data/notification_record_repository.dart';
import 'package:optimeal/features/notification/data/notification_service.dart';
import 'package:optimeal/features/notification/domain/notification_planner.dart';
import 'package:optimeal/features/notification/domain/notification_record.dart';
import 'package:optimeal/features/pantry/application/pantry_providers.dart';
import 'package:optimeal/features/pantry/data/pantry_repository.dart';
import 'package:optimeal/features/pantry/domain/shelf_life.dart';

import '../helpers/fakes.dart';

PlannedNotification planned(String foodId, DateTime at, {String body = 'b'}) =>
    PlannedNotification(
      id: NotificationPlanner.stableId('$foodId|${at.day}'),
      foodId: foodId,
      title: 't',
      body: body,
      scheduledAt: at,
    );

NotificationRecord stored(
  PlannedNotification n, {
  NotificationStatus status = NotificationStatus.scheduled,
}) => NotificationRecord(
  notificationId: NotificationRecord.idFor(n),
  userId: 'u',
  foodId: n.foodId,
  title: n.title,
  body: n.body,
  scheduledAt: n.scheduledAt,
  status: status,
);

void main() {
  final now = DateTime(2026, 11, 20, 10);
  final tomorrow = DateTime(2026, 11, 21, 9);
  final today9 = DateTime(2026, 11, 20, 9);

  group('diffNotificationRecords', () {
    test('writes only new or changed reminders', () {
      final same = planned('a', tomorrow);
      final changed = planned('b', tomorrow, body: 'new text');
      final fresh = planned('c', tomorrow);
      final changes = diffNotificationRecords(
        storedScheduled: [stored(same), stored(planned('b', tomorrow))],
        plan: [same, changed, fresh],
        userId: 'u',
        now: now,
      );
      expect(changes.upserts.map((r) => r.foodId), ['b', 'c']);
      expect(changes.statusUpdates, isEmpty);
    });

    test('passed reminders become delivered, future ones cancelled', () {
      final shown = planned('a', today9);
      final dropped = planned('b', tomorrow);
      final changes = diffNotificationRecords(
        storedScheduled: [stored(shown), stored(dropped)],
        plan: const [],
        userId: 'u',
        now: now,
      );
      expect(changes.statusUpdates, {
        NotificationRecord.idFor(shown): NotificationStatus.delivered,
        NotificationRecord.idFor(dropped): NotificationStatus.cancelled,
      });
    });

    test('nothing to do when the schedule is unchanged', () {
      final n = planned('a', tomorrow);
      expect(
        diffNotificationRecords(
          storedScheduled: [stored(n)],
          plan: [n],
          userId: 'u',
          now: now,
        ).isEmpty,
        isTrue,
      );
    });
  });

  test('recordsToMarkRead picks shown, unread reminders only', () {
    final delivered = stored(
      planned('a', today9),
      status: NotificationStatus.delivered,
    );
    final future = stored(planned('a', tomorrow));
    final cancelled = stored(
      planned('a', DateTime(2026, 11, 19, 9)),
      status: NotificationStatus.cancelled,
    );
    expect(recordsToMarkRead([delivered, future, cancelled], now), [
      delivered.notificationId,
    ]);
  });

  test('Firestore mapping round-trips (Contracts §3.4)', () {
    final r = stored(planned('summary', tomorrow));
    final doc = notificationRecordToFirestore(r);
    expect(doc['scheduledAt'], isA<Timestamp>());
    expect(doc['status'], 'scheduled');
    final back = notificationRecordFromFirestore(
      r.notificationId,
      doc.cast<String, dynamic>(),
    )!;
    expect(back.sameContentAs(r), isTrue);
    expect(
      notificationRecordFromFirestore('x', {...doc, 'status': 'spoiled'}),
      isNull,
    );
  });

  test('the sync provider saves history after scheduling', () async {
    final records = _RecordingRepository();
    final container = ProviderContainer(
      overrides: [
        pantryRepositoryProvider.overrideWithValue(fixtureRepository()),
        photoStoreProvider.overrideWithValue(MemoryPhotoStore()),
        notificationServiceProvider.overrideWithValue(_NoopService()),
        notificationRecordRepositoryProvider.overrideWithValue(records),
      ],
    );
    addTearDown(container.dispose);
    container.listen(notificationSyncProvider, (_, _) {});
    await container.read(pantryControllerProvider.future);
    await container
        .read(pantryControllerProvider.notifier)
        .add(
          FoodDraft(
            name: 'Spinach',
            category: 'Vegetables',
            storageLocation: StorageLocation.fridge,
            purchaseDate: dateOnly(DateTime.now()),
            shelfLifeDays: 5,
          ),
        );
    await Future<void>.delayed(Duration.zero);
    expect(records.plans.last.map((p) => p.foodId), isNotEmpty);
  });
}

class _RecordingRepository implements NotificationRecordRepository {
  final plans = <List<PlannedNotification>>[];

  @override
  Future<void> syncWithPlan(
    List<PlannedNotification> plan,
    DateTime now,
  ) async => plans.add(plan);

  @override
  Future<void> markRead(String foodId, DateTime now) async {}
}

class _NoopService implements NotificationService {
  @override
  Stream<String> get taps => const Stream.empty();
  @override
  Future<void> init() async {}
  @override
  Future<void> requestPermissions() async {}
  @override
  Future<void> cancelAll() async {}
  @override
  Future<String?> launchPayload() async => null;
  @override
  Future<void> replaceAll(
    List<PlannedNotification> plan,
    NotificationSettings settings,
  ) async {}
}
