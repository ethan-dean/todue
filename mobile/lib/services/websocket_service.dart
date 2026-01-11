import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import '../config/environment.dart';

enum WebSocketMessageType {
  TODOS_CHANGED,      // Single date changed - refetch that date
  RECURRING_CHANGED,  // Recurring pattern changed - refetch all visible dates
}

class WebSocketMessage {
  final WebSocketMessageType type;
  final dynamic data;

  WebSocketMessage({
    required this.type,
    required this.data,
  });

  factory WebSocketMessage.fromJson(Map<String, dynamic> json) {
    return WebSocketMessage(
      type: WebSocketMessageType.values.firstWhere(
        (e) => e.name == json['type'],
      ),
      data: json['data'],
    );
  }
}

class WebSocketService {
  static final String wsUrl = Environment.wsUrl;

  static WebSocketService get instance => websocketService;

  WebSocketChannel? _channel;
  String? _token;
  int? _userId;

  final _messageController = StreamController<WebSocketMessage>.broadcast();
  Stream<WebSocketMessage> get messageStream => _messageController.stream;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectDelay = Duration(seconds: 3);

  /// Connect to WebSocket with JWT token
  Future<void> connect(String token, int userId) async {
    _token = token;
    _userId = userId;

    try {
      // Create WebSocket connection with JWT token in query parameter
      // Backend WebSocketAuthInterceptor validates this token during handshake
      final uri = Uri.parse('$wsUrl/websocket?token=$token');
      _channel = WebSocketChannel.connect(uri);

      // Listen to incoming messages
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
      );

      // Send CONNECT frame with JWT token
      _sendConnectFrame(token, userId);

      _isConnected = true;
      _reconnectAttempts = 0;

      print('WebSocket connected');
    } catch (e) {
      print('WebSocket connection error: $e');
      _handleReconnect();
    }
  }

  /// Send STOMP CONNECT frame
  void _sendConnectFrame(String token, int userId) {
    final connectFrame = '''CONNECT
Authorization:Bearer $token
accept-version:1.1,1.0
heart-beat:10000,10000

\x00''';
    _channel?.sink.add(connectFrame);

    // Subscribe to user channel after connecting
    _subscribeToUserChannel(userId);
  }

  /// Subscribe to user-specific channel
  void _subscribeToUserChannel(int userId) {
    final subscribeFrame = '''SUBSCRIBE
id:sub-0
destination:/user/$userId/queue/updates

\x00''';

    // Delay subscription to ensure connection is established
    Future.delayed(const Duration(milliseconds: 500), () {
      _channel?.sink.add(subscribeFrame);
      print('Subscribed to user channel: $userId');
    });
  }

  /// Handle incoming messages
  void _handleMessage(dynamic message) {
    try {
      final String messageStr = message.toString();

      // Parse STOMP frame
      if (messageStr.startsWith('MESSAGE')) {
        // Extract message body from STOMP frame
        final parts = messageStr.split('\n\n');
        if (parts.length > 1) {
          final body = parts[1].replaceAll('\x00', '');

          if (body.isNotEmpty) {
            final json = jsonDecode(body) as Map<String, dynamic>;
            final wsMessage = WebSocketMessage.fromJson(json);

            _messageController.add(wsMessage);
          }
        }
      } else if (messageStr.startsWith('CONNECTED')) {
        print('WebSocket STOMP connected');
      } else if (messageStr.startsWith('ERROR')) {
        print('WebSocket STOMP error: $messageStr');
      }
    } catch (e) {
      print('Error parsing WebSocket message: $e');
    }
  }

  /// Handle WebSocket errors
  void _handleError(dynamic error) {
    print('WebSocket error: $error');
    _isConnected = false;
  }

  /// Handle WebSocket disconnection
  void _handleDisconnect() {
    print('WebSocket disconnected');
    _isConnected = false;
    // Only reconnect if we didn't intentionally disconnect (token is still present)
    if (_token != null) {
      _handleReconnect();
    }
  }

  /// Handle reconnection logic
  void _handleReconnect() {
    if (_reconnectAttempts < _maxReconnectAttempts && _token != null && _userId != null) {
      _reconnectAttempts++;
      print('Attempting to reconnect... ($_reconnectAttempts/$_maxReconnectAttempts)');

      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(_reconnectDelay, () {
        if (_token != null && _userId != null) {
          connect(_token!, _userId!);
        }
      });
    } else if (_reconnectAttempts >= _maxReconnectAttempts) {
      print('Max reconnection attempts reached');
    }
  }

  /// Disconnect from WebSocket
  void disconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    // Clear credentials immediately to prevent auto-reconnect
    _token = null;
    _userId = null;

    if (_channel != null) {
      try {
        // Send DISCONNECT frame
        final disconnectFrame = 'DISCONNECT\n\n\x00';
        _channel?.sink.add(disconnectFrame);

        // Close the channel with normal closure code (1000)
        _channel?.sink.close(status.normalClosure);
      } catch (e) {
        print('Error closing WebSocket: $e');
      }
      _channel = null;
    }

    _isConnected = false;
    _reconnectAttempts = 0;

    print('WebSocket disconnected');
  }

  /// Clean up resources
  void dispose() {
    disconnect();
    _messageController.close();
  }
}

// Singleton instance
final websocketService = WebSocketService();
