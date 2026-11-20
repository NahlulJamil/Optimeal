/// Build-time configuration (`--dart-define`).
///
/// * `USE_MOCK=true` (default) makes the API layer read fixtures instead of
///   HTTP (Contracts §6.6).
/// * `AI_PROXY_URL` is the Cloudflare Worker deployed by Developer 1. The URL
///   is not a secret; the Gemini key never leaves the Worker.
abstract final class AppConfig {
  static const String aiProxyUrl = String.fromEnvironment(
    'AI_PROXY_URL',
    defaultValue: 'https://optimeal-ai.nahluljamil-a.workers.dev',
  );

  static const bool _useMockFlag = bool.fromEnvironment(
    'USE_MOCK',
    defaultValue: true,
  );

  /// Default mock supaya Dev 2/Dev 3 bisa bekerja tanpa login dan tanpa
  /// memanggil Worker. Set `--dart-define=USE_MOCK=false` untuk mode real.
  static bool get useMock => _useMockFlag || aiProxyUrl.isEmpty;

  /// Contracts §4.1.
  static const Duration aiTimeout = Duration(seconds: 60);
  static const int aiMaxRetries = 2;
}
