import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/auth_response.dart';
import '../services/auth_api.dart';
import '../services/user_api.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../services/websocket_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  String? _token;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  String? get token => _token;
  bool get isAuthenticated => _user != null && _token != null;
  bool get isLoading => _isLoading;
  String? get error => _error;

  final AuthApi _authApi;
  final UserApi _userApi;
  final ApiService _apiService;
  final DatabaseService _databaseService;
  final WebSocketService _websocketService;

  AuthProvider({
    AuthApi? authApi,
    UserApi? userApi,
    ApiService? apiService,
    DatabaseService? databaseService,
    WebSocketService? websocketService,
  })  : _authApi = authApi ?? AuthApi.instance,
        _userApi = userApi ?? UserApi.instance,
        _apiService = apiService ?? ApiServiceInstance.instance,
        _databaseService = databaseService ?? DatabaseService.instance,
        _websocketService = websocketService ?? WebSocketService.instance {
    // Check authentication on initialization
    checkAuth();
  }

  /// Check if user is authenticated (on app start)
  Future<void> checkAuth() async {
    _setLoading(true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final storedToken = prefs.getString('token');
      final storedUserJson = prefs.getString('user');

      if (storedToken != null && storedUserJson != null) {
        _token = storedToken;
        await _apiService.setToken(storedToken);

        // Try to fetch current user to verify token is still valid
        try {
          final currentUser = await _userApi.getCurrentUser();
          _user = currentUser;

          // Save to local database
          await _databaseService.saveUser(currentUser);

          // Connect to WebSocket
          await _websocketService.connect(storedToken, currentUser.id);

          notifyListeners();
        } catch (e) {
          // Token is invalid, clear everything
          print('Token validation failed: $e');
          await logout();
        }
      }
    } catch (e) {
      _setError('Failed to check authentication: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Register a new user
  Future<void> register({
    required String email,
    required String password,
    String? timezone,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _authApi.register(
        email: email,
        password: password,
        timezone: timezone,
      );

      await _handleAuthSuccess(response);
    } catch (e) {
      _setError('Registration failed: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Login with email and password
  Future<void> login({
    required String email,
    required String password,
  }) async {
    print('AuthProvider: login called for $email');
    _setLoading(true);
    _clearError();

    try {
      print('AuthProvider: sending login request...');
      final response = await _authApi.login(
        email: email,
        password: password,
      );
      print('AuthProvider: login response received');

      await _handleAuthSuccess(response);
      print('AuthProvider: login success handled');
    } catch (e, stackTrace) {
      print('AuthProvider: Login failed: $e');
      print(stackTrace);
      _setError('Login failed: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Handle successful authentication
  Future<void> _handleAuthSuccess(AuthResponse response) async {
    print('AuthProvider: handling auth success');
    _user = response.user;
    _token = response.token;
    print('AuthProvider: user and token set in memory');

    // Store in shared preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', response.token);
    await prefs.setString('user', response.user.toJson().toString());
    print('AuthProvider: stored in SharedPreferences');

    // Set token in API service
    await _apiService.setToken(response.token);
    print('AuthProvider: token set in ApiService');

    // Save user to local database
    try {
      await _databaseService.saveUser(response.user);
      print('AuthProvider: user saved to DatabaseService');
    } catch (e) {
      print('AuthProvider: Error saving user to DB: $e');
    }

    // Connect to WebSocket
    try {
      await _websocketService.connect(response.token, response.user.id);
      print('AuthProvider: WebSocket connected');
    } catch (e) {
      print('AuthProvider: Error connecting WebSocket: $e');
    }

    notifyListeners();
    print('AuthProvider: listeners notified');
  }

  /// Logout
  Future<void> logout() async {
    _setLoading(true);

    try {
      // Clear shared preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');
      await prefs.remove('user');

      // Clear API service token
      await _apiService.clearToken();

      // Disconnect WebSocket
      _websocketService.disconnect();

      // Clear local database
      await _databaseService.clearAllData();

      // Clear state
      _user = null;
      _token = null;

      notifyListeners();
    } catch (e) {
      _setError('Logout failed: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Request password reset
  Future<void> requestPasswordReset({required String email}) async {
    _setLoading(true);
    _clearError();

    try {
      await _authApi.requestPasswordReset(email: email);
    } catch (e) {
      _setError('Password reset request failed: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Reset password with token
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      await _authApi.resetPassword(
        token: token,
        newPassword: newPassword,
      );
    } catch (e) {
      _setError('Password reset failed: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Verify email address with token
  Future<void> verifyEmail({required String token}) async {
    _setLoading(true);
    _clearError();

    try {
      await _authApi.verifyEmail(token: token);
    } catch (e) {
      _setError('Email verification failed: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Update user timezone
  Future<void> updateTimezone({required String timezone}) async {
    _setLoading(true);
    _clearError();

    try {
      final updatedUser = await _userApi.updateTimezone(timezone: timezone);
      _user = updatedUser;

      // Update in shared preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user', updatedUser.toJson().toString());

      // Update in local database
      await _databaseService.saveUser(updatedUser);

      notifyListeners();
    } catch (e) {
      _setError('Failed to update timezone: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Helper methods

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _clearError();
  }
}
