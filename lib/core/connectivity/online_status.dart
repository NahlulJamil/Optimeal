import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the device is online.
///
/// Connectivity detection and the "Mode Offline" banner belong to
/// Developer 1's offline layer. Until that exists this defaults to `true`;
/// Developer 1 only has to call [OnlineStatus.set] (or override the provider).
/// Every write / AI action in Developer 2's screens reads this provider so the
/// buttons are disabled with an explanation when offline (PRD §2.4).
class OnlineStatus extends Notifier<bool> {
  @override
  bool build() => true;

  void set(bool online) => state = online;
}

final onlineStatusProvider = NotifierProvider<OnlineStatus, bool>(
  OnlineStatus.new,
);

/// Shown next to disabled buttons while offline.
const String offlineActionMessage =
    'You are offline. Changing data needs an internet connection.';
