import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/models/food_item.dart';
import '../../auth/application/auth_providers.dart';
import '../../pantry/application/pantry_providers.dart';
import '../../pantry/domain/shelf_life.dart';
import '../data/notification_record_repository.dart';
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

/// Reminder history in Firestore for the signed-in user (real mode only).
final notificationRecordRepositoryProvider =
    Provider<NotificationRecordRepository>((ref) {
      if (AppConfig.useMock) return const NoopNotificationRecordRepository();
      final user = ref.watch(authStateProvider).value;
      if (user == null) return const NoopNotificationRecordRepository();
      return FirestoreNotificationRecordRepository(userId: user.uid);
    });

/// Keeps the scheduled reminders in sync with the pantry (PRD §3.6):
/// rebuilt when the app opens, when pantry data changes and when the
/// preferences change. Watch this provider once at the app root.
final notificationSyncProvider = Provider<void>((ref) {
  final settings = ref.watch(notificationSettingsProvider);
  final items = ref.watch(pantryControllerProvider).value;
  if (items == null) return;
  final now = DateTime.now();
  final plan = ref
      .read(notificationPlannerProvider)
      .plan(items, settings, now: now);
  final records = ref.read(notificationRecordRepositoryProvider);
  unawaited(() async {
    await ref.read(notificationServiceProvider).replaceAll(plan, settings);
    try {
      await records.syncWithPlan(plan, now);
    } catch (e) {
      // History is best effort; the reminders are already scheduled.
      debugPrint('Notification history not saved: $e');
    }
  }());
});

/// Called when the user opens a reminder (deep link).
Future<void> markNotificationRead(WidgetRef ref, String foodId) async {
  try {
    await ref
        .read(notificationRecordRepositoryProvider)
        .markRead(foodId, DateTime.now());
  } catch (e) {
    debugPrint('Notification not marked as read: $e');
  }
}

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
