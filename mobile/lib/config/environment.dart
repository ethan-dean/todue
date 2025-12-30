class Environment {
  // Development
  static const String devApiUrl = 'http://localhost:8080/api';
  static const String devWsUrl = 'ws://localhost:8080/ws';

  // Production
  static const String prodApiUrl = 'https://todue.ethandean.dev/api';
  static const String prodWsUrl = 'wss://todue.ethandean.dev/ws';

  // Current environment
  static const bool isProduction = bool.fromEnvironment('dart.vm.product');

  // Get current API URL
  static String get apiUrl => isProduction ? prodApiUrl : devApiUrl;
  static String get wsUrl => isProduction ? prodWsUrl : devWsUrl;

  // Debug info
  static void printEnvironment() {
    print('=== Environment Configuration ===');
    print('Mode: ${isProduction ? "PRODUCTION" : "DEVELOPMENT"}');
    print('API URL: $apiUrl');
    print('WebSocket URL: $wsUrl');
    print('================================');
  }
}
