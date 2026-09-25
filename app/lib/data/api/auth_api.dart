import 'api_client.dart';

/// A code request, from either OTP path.
///
/// Real path (Firebase Phone Auth on Android/iOS): [verificationId] is the
/// handle the typed SMS code is verified against, [resendToken] makes a resend
/// count as the same request, and [autoIdToken] is set when Android verified
/// the number by itself before this screen even opened.
///
/// Dev path (POST /auth/send-otp, used on web/desktop and whenever Firebase is
/// unavailable): [devOtp] carries the code while the backend has no SMS
/// provider (OTP_SHOW_IN_RESPONSE) and the OTP screen shows it in a card.
class OtpRequest {
  final String phone;
  final String? devOtp;
  final int expiresInSeconds;
  final String? verificationId;
  final int? resendToken;
  final String? autoIdToken;

  const OtpRequest({
    required this.phone,
    this.devOtp,
    this.expiresInSeconds = 300,
    this.verificationId,
    this.resendToken,
    this.autoIdToken,
  });

  /// True when the code came from Firebase, so it must be verified there
  /// rather than against POST /auth/verify-otp.
  bool get isFirebase => verificationId != null || autoIdToken != null;
}

class LoginResult {
  final String token;
  final bool isDoctor;
  final bool isNewUser;
  const LoginResult({required this.token, required this.isDoctor, this.isNewUser = false});
}

/// Unauthenticated login calls. Patients log in with phone + a server-issued
/// OTP; doctors log in with the email + password the Admin gave them.
class AuthApi {
  AuthApi._();

  static Future<OtpRequest> sendOtp(String phone) async {
    final res = await ApiClient.instance.dio.post('/auth/send-otp', data: {'phone': phone});
    return OtpRequest(
      phone: phone,
      devOtp: res.data['devOtp'] as String?,
      expiresInSeconds: (res.data['expiresInSeconds'] as num?)?.toInt() ?? 300,
    );
  }

  static Future<LoginResult> verifyOtp(String phone, String otp) async {
    final res = await ApiClient.instance.dio.post('/auth/verify-otp', data: {'phone': phone, 'otp': otp});
    return LoginResult(
      token: res.data['token'] as String,
      isDoctor: false,
      isNewUser: (res.data['user']?['name'] as String?) == 'New User',
    );
  }

  /// Trades a Firebase ID token (from real phone verification) for our own JWT.
  static Future<LoginResult> firebaseLogin(String idToken) async {
    final res = await ApiClient.instance.dio.post('/auth/firebase', data: {'idToken': idToken});
    return LoginResult(
      token: res.data['token'] as String,
      isDoctor: (res.data['role'] as String?) == 'DOCTOR',
      isNewUser: (res.data['user']?['name'] as String?) == 'New User',
    );
  }

  static Future<LoginResult> doctorLogin(String email, String password) async {
    final res = await ApiClient.instance.dio.post('/auth/doctor/login', data: {'email': email, 'password': password});
    return LoginResult(token: res.data['token'] as String, isDoctor: true);
  }
}
