import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Freshness of the local Pantry copy relative to Firestore (PRD §7.5).
enum SyncPhase {
  /// The last read/write reached Firestore while online.
  synced,

  /// A read/write is in flight.
  syncing,

  /// No connection; the list is read from the local cache.
  offline,

  /// The last read/write failed.
  error,
}

/// Current sync phase plus the last time Firestore answered successfully.
class SyncStatus {
  const SyncStatus({this.phase = SyncPhase.syncing, this.lastSyncedAt});

  final SyncPhase phase;
  final DateTime? lastSyncedAt;

  SyncStatus copyWith({SyncPhase? phase, DateTime? lastSyncedAt}) => SyncStatus(
    phase: phase ?? this.phase,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
  );
}

/// Tracks whether Pantry data is fresh and remembers the last successful sync
/// across app restarts (PRD §7.5).
///
/// The timestamp is device-level. When the Profile/logout flow lands it must
/// call [SyncStatusController.clear] so the next account starts fresh.
class SyncStatusController extends Notifier<SyncStatus> {
  static const lastSyncedKey = 'sync.lastSyncedAt';

  @override
  SyncStatus build() {
    unawaited(_restore());
    return const SyncStatus();
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(lastSyncedKey);
      final at = raw == null ? null : DateTime.tryParse(raw);
      if (at != null && state.lastSyncedAt == null) {
        state = state.copyWith(lastSyncedAt: at);
      }
    } on Object {
      // Local storage is unavailable (e.g. unit tests); start empty.
    }
  }

  void markSyncing() => state = state.copyWith(phase: SyncPhase.syncing);

  void markSynced(DateTime at) {
    state = SyncStatus(phase: SyncPhase.synced, lastSyncedAt: at);
    unawaited(_persist(at));
  }

  void markOffline() => state = state.copyWith(phase: SyncPhase.offline);

  void markError() => state = state.copyWith(phase: SyncPhase.error);

  Future<void> clear() async {
    state = const SyncStatus();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(lastSyncedKey);
    } on Object {
      // Nothing to clear when storage is unavailable.
    }
  }

  Future<void> _persist(DateTime at) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(lastSyncedKey, at.toUtc().toIso8601String());
    } on Object {
      // Best effort; the in-memory status still updates.
    }
  }
}

final syncStatusProvider = NotifierProvider<SyncStatusController, SyncStatus>(
  SyncStatusController.new,
);

/// "just now" / "5 min ago" / "2 h ago" / "3 d ago" for the sync line.
String formatLastSynced(DateTime at, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(at);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  return '${diff.inDays} d ago';
}
