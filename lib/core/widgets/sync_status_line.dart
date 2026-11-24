import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../connectivity/sync_status.dart';
import '../theme/app_colors.dart';

/// One-line freshness indicator for Pantry (PRD §7.5).
///
/// The Figma Pantry frame has no slot for this row; it reuses existing color
/// tokens so it stays visually consistent. Report to the team before changing
/// its placement or wording.
class SyncStatusLine extends ConsumerWidget {
  const SyncStatusLine({super.key, this.now});

  /// Injection point for tests; defaults to [DateTime.now].
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider);
    final (icon, color, label) = switch (status.phase) {
      SyncPhase.syncing => (
        Icons.sync,
        AppColors.textSecondary,
        'Syncing…',
      ),
      SyncPhase.offline => (
        Icons.cloud_off_outlined,
        AppColors.warning,
        _offlineLabel(status, now),
      ),
      SyncPhase.error => (
        Icons.error_outline,
        AppColors.danger,
        _errorLabel(status, now),
      ),
      SyncPhase.synced => (
        Icons.cloud_done_outlined,
        AppColors.primary,
        _syncedLabel(status, now),
      ),
    };

    return Row(
      key: const Key('sync-status-line'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  String _syncedLabel(SyncStatus status, DateTime? now) {
    final at = status.lastSyncedAt;
    return at == null ? 'Synced' : 'Synced ${formatLastSynced(at, now: now)}';
  }

  String _offlineLabel(SyncStatus status, DateTime? now) {
    final at = status.lastSyncedAt;
    return at == null
        ? 'Offline · No cached data yet'
        : 'Offline · Last synced ${formatLastSynced(at, now: now)}';
  }

  String _errorLabel(SyncStatus status, DateTime? now) {
    final at = status.lastSyncedAt;
    return at == null
        ? 'Could not sync'
        : 'Could not sync · Last synced ${formatLastSynced(at, now: now)}';
  }
}
