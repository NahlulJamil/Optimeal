import 'dart:async';

import 'package:optimeal/core/config/app_config.dart';

/// Runs before every test file. The app defaults to real Firebase + Worker
/// (Contracts §6.6); unit and widget tests run against the fixtures instead,
/// so no test ever reaches the network or needs Firebase initialised.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  AppConfig.debugUseMockOverride = true;
  await testMain();
}
