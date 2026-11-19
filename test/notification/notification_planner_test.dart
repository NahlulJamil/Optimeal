import 'package:flutter_test/flutter_test.dart';
import 'package:optimeal/core/models/food_item.dart';
import 'package:optimeal/features/notification/domain/notification_planner.dart';

FoodItem food(String id, String name, DateTime end) => FoodItem(
  foodId: id,
  userId: 'u',
  name: name,
  category: 'Vegetables',
  storageLocation: StorageLocation.fridge,
  purchaseDate: DateTime(2026, 11, 1),
  shelfLifeDays: 1,
  estimatedEndDate: end,
  hasPhoto: false,
  createdAt: DateTime(2026, 11, 1),
  updatedAt: DateTime(2026, 11, 1),
);

void main() {
  const planner = NotificationPlanner();
  final now = DateTime(2026, 11, 20, 10);

  test('schedules H-threshold and H-0 at 09:00, at most two per food', () {
    final plan = planner.plan(
      [food('a', 'Spinach', DateTime(2026, 11, 25))],
      const NotificationSettings(thresholdDays: 2),
      now: now,
    );
    expect(plan.map((p) => p.scheduledAt), [
      DateTime(2026, 11, 23, 9),
      DateTime(2026, 11, 25, 9),
    ]);
    expect(plan.first.body, 'Your Spinach has ±2 days left. Cook it soon.');
    expect(plan.last.title, 'Last day of the shelf-life estimate');
    expect(plan.every((p) => p.foodId == 'a'), isTrue);
  });

  test('skips reminders in the past (rule 7)', () {
    final plan = planner.plan(
      [
        food('past', 'Milk', DateTime(2026, 11, 18)),
        food('today', 'Tomato', DateTime(2026, 11, 20)),
        food('tomorrow', 'Egg', DateTime(2026, 11, 21)),
      ],
      const NotificationSettings(),
      now: now,
    );
    // Today 09:00 is already past at 10:00; tomorrow's H-1 is today 09:00
    // (past) but its H-0 is still ahead.
    expect(plan.map((p) => p.foodId), ['tomorrow']);
    expect(plan.single.scheduledAt, DateTime(2026, 11, 21, 9));
  });

  test('more than 3 on one day → 3 individual + 1 summary (rule 5)', () {
    final end = DateTime(2026, 11, 22);
    final items = [for (var i = 0; i < 8; i++) food('f$i', 'Food $i', end)];
    final plan = planner.plan(items, const NotificationSettings(), now: now);
    // Two days involved: H-1 (21st) and H-0 (22nd).
    for (final day in [21, 22]) {
      final ofDay = plan.where((p) => p.scheduledAt.day == day).toList();
      expect(ofDay.where((p) => !p.isSummary), hasLength(3));
      final summary = ofDay.singleWhere((p) => p.isSummary);
      expect(summary.body, contains('5 more items'));
    }
  });

  test('fewest days left wins the individual slots', () {
    final plan = planner.plan(
      [
        // H-0 of these three falls on the 23rd...
        food('a', 'A', DateTime(2026, 11, 23)),
        food('b', 'B', DateTime(2026, 11, 23)),
        food('c', 'C', DateTime(2026, 11, 23)),
        // ...and H-1 of this one too.
        food('d', 'D', DateTime(2026, 11, 24)),
      ],
      const NotificationSettings(),
      now: now,
    );
    final day23 = plan.where((p) => p.scheduledAt.day == 23).toList();
    expect(day23.where((p) => !p.isSummary).map((p) => p.foodId), [
      'a',
      'b',
      'c',
    ]);
    expect(day23.where((p) => p.isSummary), hasLength(1));
  });

  test('disabled → nothing; Indonesian copy never says basi', () {
    final items = [food('a', 'Bayam', DateTime(2026, 11, 23))];
    expect(
      planner.plan(items, const NotificationSettings(enabled: false), now: now),
      isEmpty,
    );
    final plan = planner.plan(
      items,
      const NotificationSettings(language: 'id', thresholdDays: 2),
      now: now,
    );
    expect(
      plan.first.body,
      'Bayam kamu tinggal ±2 hari lagi. Yuk segera diolah.',
    );
    expect(
      plan.last.body,
      'Hari ini batas estimasi masa simpan Bayam. Periksa kondisinya.',
    );
    for (final p in plan) {
      expect(p.body.toLowerCase(), isNot(contains('basi')));
    }
  });

  test('ids are stable and distinct', () {
    final a = NotificationPlanner.stableId('f1|0');
    expect(NotificationPlanner.stableId('f1|0'), a);
    expect(NotificationPlanner.stableId('f1|1'), isNot(a));
    expect(a, lessThanOrEqualTo(0x7fffffff));
  });
}
