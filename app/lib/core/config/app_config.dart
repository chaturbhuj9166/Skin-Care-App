/// Backend base URL. Override at build/run time with:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000   (Android emulator)
///   flutter run --dart-define=API_BASE_URL=http://192.168.x.x:5000 (physical device on same LAN)
/// Defaults to localhost, which works for Windows/macOS/Linux desktop runs and
/// the Chrome/web target against a backend running on the same machine.
class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:5000',
  );
}
