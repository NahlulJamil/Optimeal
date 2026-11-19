import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/food_item.dart';
import '../../pantry/application/pantry_providers.dart';
import '../../pantry/domain/shelf_life.dart';
import '../data/notification_service.dart';
import '../domain/notification_planner.dart';

/// Notification preferences. Profile → Notifications (Developer 1) writes
/// here; persisting them to `users/{uid}` is part of Developer 1's profile
/// work (`notificationsEnabled`, `notificationThresholdDays`).
class NotificationSettingsController extends Notifier<NotificationSettings> {
  @override
  NotificationSettings build() => const NotificationSettings();

  void setEnabled(bool enabled) => state = state.copyWith(enabled: enabled);

  void setThresholdDays(int days) =>
      state = state.copyWith(thresholdDays: days.clamp(1, 3));

  void setLanguage(String language) =>
      state = state.copyWith(language: language);
}

final notificationSettingsProvider =
    NotifierProvider<NotificationSettingsController, NotificationSettings>(
      NotificationSettingsController.new,
    );

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => LocalNotificationService(),
);

final notificationPlannerProvider = Provider<NotificationPlanner>(
  (ref) => const NotificationPlanner(),
);

/// Keeps the scheduled reminders in sync with the pantry (PRD §3.6):
/// rebuilt when the app opens, when pantry data changes and when the
/// preferences change. Watch this provider once at the app root.
final notificationSyncProvider = Provider<void>((ref) {
  final settings = ref.watch(notificationSettingsProvider);
  final items = ref.watch(pantryControllerProvider).value;
  if (items == null) return;
  final plan = ref
      .read(notificationPlannerProvider)
      .plan(items, settings, now: DateTime.now());
  unawaited(ref.read(notificationServiceProvider).replaceAll(plan, settings));
});

/// Items inside the reminder window, closest first. For the Home warning
/// banner (Developer 1) and the in-app [ExpiringBanner].
final expiringSoonProvider = Provider<List<FoodItem>>((ref) {
  final threshold = ref.watch(notificationSettingsProvider).thresholdDays;
  final items = ref.watch(pantryControllerProvider).value ?? const [];
  return items.where((i) {
    final d = daysLeft(i);
    return d >= 0 && d <= threshold;
  }).toList();
});
