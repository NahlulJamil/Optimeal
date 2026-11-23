import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'online_status.dart';

/// Keeps [onlineStatusProvider] in sync with the device connection so Home can
/// show the "Mode Offline" indicator and write actions disable themselves
/// (PRD §2.4, §3.2, §4.7).
///
/// Wrap the widget tree once; it owns no UI of its own.
class ConnectivityWatcher extends ConsumerStatefulWidget {
  const ConnectivityWatcher({
    super.key,
    required this.child,
    this.connectivity,
  });

  final Widget child;

  /// Injection point for tests; defaults to [Connectivity].
  final Connectivity? connectivity;

  @override
  ConsumerState<ConnectivityWatcher> createState() =>
      _ConnectivityWatcherState();
}

class _ConnectivityWatcherState extends ConsumerState<ConnectivityWatcher> {
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  @override
  void initState() {
    super.initState();
    final connectivity = widget.connectivity ?? Connectivity();
    _subscription = connectivity.onConnectivityChanged.listen(_update);
    unawaited(_readInitial(connectivity));
  }

  Future<void> _readInitial(Connectivity connectivity) async {
    try {
      _update(await connectivity.checkConnectivity());
    } on Object {
      // Keep the default (online) state; the stream will correct it.
    }
  }

  void _update(List<ConnectivityResult> results) {
    if (!mounted) return;
    final online = results.any((result) => result != ConnectivityResult.none);
    ref.read(onlineStatusProvider.notifier).set(online);
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
