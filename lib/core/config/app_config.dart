/// Build-time configuration (`--dart-define`).
///
/// * `USE_MOCK=true` makes the API layer read fixtures instead of HTTP
///   (Contracts §6.6).
/// * `AI_PROXY_URL=https://optimeal-ai.<subdomain>.workers.dev` is the
///   Cloudflare Worker deployed by Developer 1. While it is not configured the
///   app also uses the mock, so the scanner can be developed without it.
abstract final class AppConfig {
  static const String aiProxyUrl = String.fromEnvironment('AI_PROXY_URL');
  static const bool _useMockFlag = bool.fromEnvironment('USE_MOCK');

  static bool get useMock => _useMockFlag || aiProxyUrl.isEmpty;

  /// Contracts §4.1.
  static const Duration aiTimeout = Duration(seconds: 60);
  static const int aiMaxRetries = 2;
}
