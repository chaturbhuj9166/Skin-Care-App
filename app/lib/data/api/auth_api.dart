import 'api_client.dart';

/// Result of POST /auth/send-otp. [devOtp] is only present while the backend
/// has no SMS provider (OTP_SHOW_IN_RESPONSE) - the OTP screen then shows it.
class OtpRequest {
  final String phone;
  final String? devOtp;
  final int expiresInSeconds;
  const OtpRequest({required this.phone, this.devOtp, this.expiresInSeconds = 300});
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

  static Future<LoginResult> doctorLogin(String email, String password) async {
    final res = await ApiClient.instance.dio.post('/auth/doctor/login', data: {'email': email, 'password': password});
    return LoginResult(token: res.data['token'] as String, isDoctor: true);
  }
}
