import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/api/api_client.dart';
import '../../data/api/socket_service.dart';

enum AppRole { user, doctor }

class SessionState {
  final bool loading;
  final bool onboardingSeen;
  final bool loggedIn;
  final String? token;
  final AppRole? role;

  const SessionState({this.loading = true, this.onboardingSeen = false, this.loggedIn = false, this.token, this.role});

  SessionState copyWith({bool? loading, bool? onboardingSeen, bool? loggedIn, String? token, AppRole? role}) => SessionState(
        loading: loading ?? this.loading,
        onboardingSeen: onboardingSeen ?? this.onboardingSeen,
        loggedIn: loggedIn ?? this.loggedIn,
        token: token ?? this.token,
        role: role ?? this.role,
      );
}

/// Persists the real JWT issued by the backend (via flutter_secure_storage)
/// and keeps ApiClient/SocketService in sync with it. A single instance
/// serves both the User and Doctor experiences of this one app - `role`
/// (decided by the server at OTP verification, based on which table the
/// phone number matched) is what the router uses to send a logged-in user
/// to the right home screen.
class SessionController extends StateNotifier<SessionState> {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'app_token';
  static const _roleKey = 'app_role';
  static const _onboardingKey = 'app_onboarding_seen';

  SessionController() : super(const SessionState()) {
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      _storage.read(key: _tokenKey),
      _storage.read(key: _roleKey),
      SharedPreferences.getInstance(),
    ]);
    final token = results[0] as String?;
    final roleStr = results[1] as String?;
    final prefs = results[2] as SharedPreferences;
    final role = roleStr == 'DOCTOR' ? AppRole.doctor : (roleStr == 'USER' ? AppRole.user : null);

    if (token != null) {
      ApiClient.instance.setToken(token);
      SocketService.instance.connect(token);
    }

    state = SessionState(
      loading: false,
      onboardingSeen: prefs.getBool(_onboardingKey) ?? false,
      loggedIn: token != null,
      token: token,
      role: role,
    );
  }

  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);
    state = state.copyWith(onboardingSeen: true);
  }

  Future<void> login(String token, AppRole role) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _roleKey, value: role == AppRole.doctor ? 'DOCTOR' : 'USER');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);
    ApiClient.instance.setToken(token);
    SocketService.instance.connect(token);
    state = state.copyWith(loggedIn: true, onboardingSeen: true, token: token, role: role);
  }

  Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _roleKey);
    ApiClient.instance.setToken(null);
    SocketService.instance.disconnect();
    state = const SessionState(loading: false, onboardingSeen: true, loggedIn: false);
  }
}

final appSessionProvider = StateNotifierProvider<SessionController, SessionState>(
  (ref) => SessionController(),
);
