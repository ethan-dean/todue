import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/environment.dart';

class ApiService {
  static final String baseUrl = Environment.apiUrl;

  late final Dio _dio;
  String? _token;

  ApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Add interceptor to attach JWT token
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Add token if available
          if (_token != null) {
            options.headers['Authorization'] = 'Bearer $_token';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          // Handle 401 Unauthorized errors
          if (error.response?.statusCode == 401) {
            await clearToken();
            // You could also trigger a logout/redirect here
          }
          return handler.next(error);
        },
      ),
    );

    // Load token from storage
    _loadToken();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
  }

  Future<void> setToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user');
  }

  String? getToken() {
    return _token;
  }

  bool isAuthenticated() {
    return _token != null && _token!.isNotEmpty;
  }

  // HTTP Methods

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Error Handling

  Exception _handleError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return Exception('Connection timeout. Please check your internet connection.');

      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        String? message;
        
        if (error.response?.data is Map) {
          message = error.response?.data['message'];
        } else if (error.response?.data is String) {
          message = error.response?.data;
        }
        
        message = message ?? error.response?.statusMessage;

        if (statusCode == 400) {
          return Exception(message ?? 'Bad request');
        } else if (statusCode == 401) {
          return Exception('Unauthorized. Please log in again.');
        } else if (statusCode == 403) {
          return Exception('Forbidden. You do not have permission.');
        } else if (statusCode == 404) {
          return Exception('Resource not found');
        } else if (statusCode == 500) {
          return Exception('Server error. Please try again later.');
        } else {
          return Exception(message ?? 'An error occurred');
        }

      case DioExceptionType.cancel:
        return Exception('Request was cancelled');

      case DioExceptionType.unknown:
        if (error.error.toString().contains('SocketException')) {
          return Exception('No internet connection');
        }
        return Exception('An unexpected error occurred');

      default:
        return Exception('An error occurred: ${error.message}');
    }
  }
}

// Singleton instance
final apiService = ApiService();

extension ApiServiceInstance on ApiService {
  static ApiService get instance => apiService;
}
