import '../../../core/models/food_item.dart';
import '../../pantry/domain/shelf_life.dart';

/// User preferences from Profile → Notifications (PRD §3.6, Contracts §3.5).
class NotificationSettings {
  const NotificationSettings({
    this.enabled = true,
    this.thresholdDays = 1,
    this.language = 'en',
  }) : assert(thresholdDays >= 1 && thresholdDays <= 3);

  final bool enabled;

  /// Reminder threshold H-{n}, 1–3 days, default 1.
  final int thresholdDays;

  /// `en` (default) or `id`.
  final String language;

  NotificationSettings copyWith({
    bool? enabled,
    int? thresholdDays,
    String? language,
  }) => NotificationSettings(
    enabled: enabled ?? this.enabled,
    thresholdDays: thresholdDays ?? this.thresholdDays,
    language: language ?? this.language,
  );
}

/// Payload used for the summary notification (opens the Pantry).
const String summaryPayload = 'summary';

class PlannedNotification {
  const PlannedNotification({
    required this.id,
    required this.foodId,
    required this.title,
    required this.body,
    required this.scheduledAt,
  });

  /// Stable id for the platform plugin.
  final int id;

  /// Food id for the deep link, or [summaryPayload].
  final String foodId;
  final String title;
  final String body;

  /// Local time.
  final DateTime scheduledAt;

  bool get isSummary => foodId == summaryPayload;

  @override
  String toString() => 'PlannedNotification($foodId @ $scheduledAt: $body)';
}

/// Pure scheduling rules from PRD §3.6 "Aturan pengiriman":
///
/// 1. reminders at H-{threshold} and H-0;
/// 2. at most two per food;
/// 3./4. the whole plan is rebuilt from the current pantry, so deleted items
///    lose their reminders and changed dates are rescheduled;
/// 5. at most 3 individual reminders per day (fewest days left first) plus
///    one summary for the rest;
/// 6. wording says "approaching the estimate" / "±N days left", never
///    "spoiled";
/// 7. nothing is scheduled in the past (so never for items more than a day
///    past H-0).
class NotificationPlanner {
  const NotificationPlanner({this.reminderHour = 9});

  /// Local hour at which reminders are shown. The PRD does not fix a time;
  /// 09:00 keeps reminders out of the night.
  final int reminderHour;

  static const int maxIndividualPerDay = 3;

  List<PlannedNotification> plan(
    Iterable<FoodItem> items,
    NotificationSettings settings, {
    required DateTime now,
  }) {
    if (!settings.enabled) return const [];
    final copy = NotificationCopy(settings.language);
    final byDay = <DateTime, List<_Candidate>>{};

    for (final item in items) {
      final end = dateOnly(item.estimatedEndDate);
      final offsets = {settings.thresholdDays, 0};
      for (final daysBefore in offsets) {
        final day = DateTime(end.year, end.month, end.day - daysBefore);
        final at = DateTime(day.year, day.month, day.day, reminderHour);
        if (!at.isAfter(now)) continue;
        byDay.putIfAbsent(day, () => []).add(_Candidate(item, daysBefore, at));
      }
    }

    final result = <PlannedNotification>[];
    final days = byDay.keys.toList()..sort();
    for (final day in days) {
      final list = byDay[day]!
        ..sort((a, b) {
          final byDays = a.daysLeft.compareTo(b.daysLeft);
          return byDays != 0
              ? byDays
              : a.item.name.toLowerCase().compareTo(b.item.name.toLowerCase());
        });
      for (final c in list.take(maxIndividualPerDay)) {
        result.add(
          PlannedNotification(
            id: stableId('${c.item.foodId}|${c.daysLeft}'),
            foodId: c.item.foodId,
            title: c.daysLeft == 0 ? copy.todayTitle : copy.soonTitle,
            body: c.daysLeft == 0
                ? copy.todayBody(c.item.name)
                : copy.soonBody(c.item.name, c.daysLeft),
            scheduledAt: c.at,
          ),
        );
      }
      final rest = list.length - maxIndividualPerDay;
      if (rest > 0) {
        result.add(
          PlannedNotification(
            id: stableId('summary|${day.toIso8601String()}'),
            foodId: summaryPayload,
            title: copy.summaryTitle,
            body: copy.summaryBody(rest),
            scheduledAt: list.first.at,
          ),
        );
      }
    }
    return result;
  }

  /// Deterministic 31-bit id (FNV-1a), stable across app runs.
  static int stableId(String key) {
    var hash = 0x811c9dc5;
    for (final unit in key.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash & 0x7fffffff;
  }
}

class _Candidate {
  _Candidate(this.item, this.daysLeft, this.at);

  final FoodItem item;
  final int daysLeft;
  final DateTime at;
}

/// Notification copy in English (default) and Indonesian (PRD §3.6 examples).
class NotificationCopy {
  const NotificationCopy(this.language);

  final String language;

  bool get _id => language == 'id';

  String get soonTitle =>
      _id ? 'Bahan mendekati batas' : 'Approaching shelf-life estimate';

  String soonBody(String name, int days) => _id
      ? '$name kamu tinggal ±$days hari lagi. Yuk segera diolah.'
      : 'Your $name has ±$days ${days == 1 ? 'day' : 'days'} left. '
            'Cook it soon.';

  String get todayTitle =>
      _id ? 'Hari terakhir estimasi' : 'Last day of the shelf-life estimate';

  String todayBody(String name) => _id
      ? 'Hari ini batas estimasi masa simpan $name. Periksa kondisinya.'
      : 'Today is the shelf-life estimate for your $name. '
            'Check its condition.';

  String get summaryTitle => _id
      ? 'Beberapa bahan mendekati batas'
      : 'More food approaching its estimate';

  String summaryBody(int count) => _id
      ? '$count bahan lain juga mendekati batas estimasi masa simpan. '
            'Cek Pantry.'
      : '$count more ${count == 1 ? 'item is' : 'items are'} also approaching '
            'the shelf-life estimate. Check your Pantry.';

  String get channelName =>
      _id ? 'Pengingat masa simpan' : 'Shelf-life reminders';

  String get channelDescription => _id
      ? 'Pengingat bahan yang mendekati batas estimasi masa simpan'
      : 'Reminders for food approaching its shelf-life estimate';
}
