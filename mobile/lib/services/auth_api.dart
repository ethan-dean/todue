import '../models/auth_response.dart';
import 'api_service.dart';

class AuthApi {
  final ApiService _apiService;

  static AuthApi get instance => authApi;

  AuthApi(this._apiService);

  /// Register a new user
  Future<AuthResponse> register({
    required String email,
    required String password,
    String? timezone,
  }) async {
    final response = await _apiService.post(
      '/auth/register',
      data: {
        'email': email,
        'password': password,
        'timezone': timezone ?? 'UTC',
      },
    );

    return AuthResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// Login with email and password
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final response = await _apiService.post(
      '/auth/login',
      data: {
        'email': email,
        'password': password,
      },
    );

    return AuthResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// Request password reset
  Future<void> requestPasswordReset({required String email}) async {
    await _apiService.post(
      '/auth/reset-password-request',
      data: {
        'email': email,
      },
    );
  }

  /// Reset password with token
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    await _apiService.post(
      '/auth/reset-password',
      data: {
        'token': token,
        'newPassword': newPassword,
      },
    );
  }

  /// Verify email address with token
  Future<Map<String, dynamic>> verifyEmail({required String token}) async {
    final response = await _apiService.get(
      '/auth/verify-email',
      queryParameters: {
        'token': token,
      },
    );

    return response.data as Map<String, dynamic>;
  }
}

// Singleton instance
final authApi = AuthApi(apiService);
