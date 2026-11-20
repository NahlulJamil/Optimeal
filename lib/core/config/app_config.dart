/// Konfigurasi runtime aplikasi.
///
/// Nilai diisi lewat `--dart-define`, contoh:
/// `flutter run --dart-define=WORKER_BASE_URL=https://... --dart-define=USE_MOCK=false`
class AppConfig {
  /// Saat `true`, layer API membaca `assets/fixtures/` dan tidak memanggil
  /// Worker. Default `true` supaya Dev 2 dan Dev 3 bisa bekerja tanpa backend.
  static const bool useMock = bool.fromEnvironment(
    'USE_MOCK',
    defaultValue: true,
  );

  /// Base URL Cloudflare Worker. URL bukan rahasia; API key tidak pernah
  /// dikirim ke client.
  static const String workerBaseUrl = String.fromEnvironment(
    'WORKER_BASE_URL',
    defaultValue: '',
  );
}
