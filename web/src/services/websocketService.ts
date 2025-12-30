import { Client, IMessage } from '@stomp/stompjs';
import SockJS from 'sockjs-client';
import { WebSocketMessage } from '../types';

const WS_URL = import.meta.env.VITE_WS_URL || 'http://localhost:8080/ws';

class WebSocketService {
  private client: Client | null = null;
  private userId: number | null = null;
  private reconnectAttempts = 0;
  private maxReconnectAttempts = 5;
  private reconnectDelay = 3000;
  private callbacks: Map<string, (message: WebSocketMessage) => void> = new Map();

  /**
   * Connect to WebSocket with JWT token
   */
  connect(token: string, userId: number): Promise<void> {
    return new Promise((resolve, reject) => {
      this.userId = userId;

      this.client = new Client({
        // Pass JWT token as query parameter for handshake authentication
        // Backend WebSocketAuthInterceptor validates this token
        webSocketFactory: () => new SockJS(`${WS_URL}?token=${token}`),
        debug: (str) => {
          console.log('STOMP: ' + str);
        },
        reconnectDelay: this.reconnectDelay,
        heartbeatIncoming: 4000,
        heartbeatOutgoing: 4000,
      });

      this.client.onConnect = () => {
        console.log('WebSocket connected');
        this.reconnectAttempts = 0;
        resolve();
      };

      this.client.onStompError = (frame) => {
        console.error('STOMP error: ' + frame.headers['message']);
        console.error('Details: ' + frame.body);
        reject(new Error(frame.headers['message']));
      };

      this.client.onWebSocketError = (event) => {
        console.error('WebSocket error:', event);
      };

      this.client.onWebSocketClose = () => {
        console.log('WebSocket connection closed');
        this.handleReconnect(token, userId);
      };

      this.client.activate();
    });
  }

  /**
   * Handle reconnection logic
   */
  private handleReconnect(token: string, userId: number): void {
    if (this.reconnectAttempts < this.maxReconnectAttempts) {
      this.reconnectAttempts++;
      console.log(`Attempting to reconnect... (${this.reconnectAttempts}/${this.maxReconnectAttempts})`);
      setTimeout(() => {
        this.connect(token, userId).catch((error) => {
          console.error('Reconnection failed:', error);
        });
      }, this.reconnectDelay);
    } else {
      console.error('Max reconnection attempts reached');
    }
  }

  /**
   * Subscribe to user's update channel
   */
  subscribe(callback: (message: WebSocketMessage) => void): void {
    if (!this.client || !this.userId) {
      console.error('WebSocket not connected or userId not set');
      return;
    }

    const destination = `/user/${this.userId}/queue/updates`;

    this.client.subscribe(destination, (message: IMessage) => {
      try {
        const wsMessage: WebSocketMessage = JSON.parse(message.body);
        callback(wsMessage);
      } catch (error) {
        console.error('Error parsing WebSocket message:', error);
      }
    });

    // Store callback for potential resubscription
    this.callbacks.set('updates', callback);
  }

  /**
   * Disconnect from WebSocket
   */
  disconnect(): void {
    if (this.client) {
      this.client.deactivate();
      this.client = null;
      this.userId = null;
      this.callbacks.clear();
      console.log('WebSocket disconnected');
    }
  }

  /**
   * Check if connected
   */
  isConnected(): boolean {
    return this.client?.connected ?? false;
  }
}

// Export singleton instance
export const websocketService = new WebSocketService();
