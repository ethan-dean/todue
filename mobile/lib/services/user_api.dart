import '../models/user.dart';
import 'api_service.dart';

class UserApi {
  final ApiService _apiService;

  static UserApi get instance => userApi;

  UserApi(this._apiService);

  /// Get current user information
  Future<User> getCurrentUser() async {
    final response = await _apiService.get('/user/me');
    return User.fromJson(response.data as Map<String, dynamic>);
  }

  /// Get current date in user's timezone
  Future<String> getCurrentDate() async {
    final response = await _apiService.get('/user/current-date');
    return response.data['currentDate'] as String;
  }

  /// Update user's timezone
  Future<User> updateTimezone({required String timezone}) async {
    final response = await _apiService.put(
      '/user/timezone',
      queryParameters: {
        'timezone': timezone,
      },
    );
    return User.fromJson(response.data as Map<String, dynamic>);
  }

  /// Update user's accent color
  Future<User> updateAccentColor({required String? accentColor}) async {
    final response = await _apiService.put(
      '/user/accent-color',
      data: {'accentColor': accentColor},
    );
    return User.fromJson(response.data as Map<String, dynamic>);
  }

  /// Get available timezones
  Future<List<String>> getTimezones() async {
    final response = await _apiService.get('/user/timezones');
    return (response.data as List).cast<String>();
  }
}

// Singleton instance
final userApi = UserApi(apiService);
