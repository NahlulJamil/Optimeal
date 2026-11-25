import 'package:flutter/foundation.dart' show visibleForTesting;

/// Build-time configuration (`--dart-define`).
///
/// * `USE_MOCK=true` (default `false`) makes the API layer read fixtures instead of
///   HTTP (Contracts §6.6).
/// * `AI_PROXY_URL` is the Cloudflare Worker deployed by Developer 1. The URL
///   is not a secret; the Gemini key never leaves the Worker.
abstract final class AppConfig {
  static const String aiProxyUrl = String.fromEnvironment(
    'AI_PROXY_URL',
    defaultValue: 'https://optimeal-ai.optimeal.workers.dev',
  );

  static const bool _useMockFlag = bool.fromEnvironment(
    'USE_MOCK',
    defaultValue: false,
  );

  /// Default mode real: login Firebase, Pantry/resep di Firestore, AI lewat
  /// Worker. Mock hanya bila diminta dengan `--dart-define=USE_MOCK=true`
  /// (Contracts §6.6) — mis. untuk mengembangkan UI tanpa kuota Gemini.
  static bool get useMock =>
      debugUseMockOverride ?? (_useMockFlag || aiProxyUrl.isEmpty);

  /// Tests only: forces mock mode on/off without `--dart-define`
  /// (set for every test in `test/flutter_test_config.dart`).
  @visibleForTesting
  static bool? debugUseMockOverride;

  /// Contracts §4.1.
  static const Duration aiTimeout = Duration(seconds: 60);
  static const int aiMaxRetries = 2;
}
