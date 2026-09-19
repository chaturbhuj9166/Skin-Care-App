import 'package:dio/dio.dart';
import '../../core/config/app_config.dart';

/// Thin Dio wrapper shared by every API call in the app. Holds the current
/// JWT in memory (set by SessionController on login/boot) and attaches it to
/// every request, so repositories never have to thread auth through by hand.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  late final Dio dio = Dio(BaseOptions(
    baseUrl: '${AppConfig.apiBaseUrl}/api',
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ))
    ..interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_token != null) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        handler.next(options);
      },
    ));

  String? _token;

  void setToken(String? token) => _token = token;
  String? get token => _token;
}

/// Extracts a human-readable message from a failed API call, matching the
/// backend's `{ error: string, details?: ... }` error envelope.
String apiErrorMessage(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['error'] is String) return data['error'] as String;
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout) {
      return 'Could not reach the server. Check your connection and try again.';
    }
  }
  return 'Something went wrong. Please try again.';
}
