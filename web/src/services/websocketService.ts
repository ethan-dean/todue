import { Client, type StompSubscription } from '@stomp/stompjs';
import SockJS from 'sockjs-client';
import type { WebSocketMessage, WebSocketMessageType } from '../types';

const WS_URL = import.meta.env.VITE_WS_URL || 'http://localhost:8080/ws';

type MessageHandler = (message: WebSocketMessage) => void;

interface TypedSubscription {
  id: string;
  types: WebSocketMessageType[];
  callback: MessageHandler;
}

class WebSocketService {
  private client: Client | null = null;
  private userId: number | null = null;
  private reconnectAttempts = 0;
  private maxReconnectAttempts = 5;
  private reconnectDelay = 3000;
  private typedSubscriptions: Map<string, TypedSubscription> = new Map();
  private connectionListeners: Array<() => void> = [];
  private subscription: StompSubscription | null = null;
  private subscriptionIdCounter = 0;

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
        // debug: (str) => {
        //   console.log('STOMP: ' + str);
        // },
        reconnectDelay: this.reconnectDelay,
        heartbeatIncoming: 4000,
        heartbeatOutgoing: 4000,
      });

      this.client.onConnect = () => {
        console.log('WebSocket connected');
        this.reconnectAttempts = 0;

        // Notify all connection listeners
        this.connectionListeners.forEach(listener => listener());
        this.connectionListeners = [];

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
   * Register a callback to be called when connection is established
   * If already connected, callback is called immediately
   */
  onConnectionEstablished(callback: () => void): void {
    if (this.isConnected()) {
      // Already connected, call immediately
      callback();
    } else {
      // Not connected yet, register for future notification
      this.connectionListeners.push(callback);
    }
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
   * Subscribe to specific message types
   * @param types Array of message types to listen for
   * @param callback Handler for matching messages
   * @returns Unsubscribe function
   */
  subscribe(types: WebSocketMessageType[], callback: MessageHandler): () => void {
    if (!this.client || !this.userId) {
      console.error('WebSocket not connected or userId not set');
      return () => {};
    }

    // Generate unique subscription ID
    const subscriptionId = `sub-${++this.subscriptionIdCounter}`;

    // Store the typed subscription
    this.typedSubscriptions.set(subscriptionId, {
      id: subscriptionId,
      types,
      callback,
    });

    // Set up STOMP subscription if not already subscribed
    if (!this.subscription) {
      this.setupStompSubscription();
    }

    // Return unsubscribe function for this specific handler
    return () => {
      this.typedSubscriptions.delete(subscriptionId);

      // If no more subscriptions, unsubscribe from STOMP
      if (this.typedSubscriptions.size === 0 && this.subscription) {
        this.subscription.unsubscribe();
        this.subscription = null;
      }
    };
  }

  /**
   * Set up the STOMP subscription that routes messages to typed handlers
   */
  private setupStompSubscription(): void {
    if (!this.client || !this.userId) return;

    const destination = `/user/${this.userId}/queue/updates`;

    this.subscription = this.client.subscribe(destination, (message) => {
      try {
        const wsMessage: WebSocketMessage = JSON.parse(message.body);
        this.routeMessage(wsMessage);
      } catch (error) {
        console.error('Error parsing WebSocket message:', error);
      }
    });
  }

  /**
   * Route incoming message to appropriate handlers based on type
   */
  private routeMessage(message: WebSocketMessage): void {
    let handled = false;

    this.typedSubscriptions.forEach((subscription) => {
      if (subscription.types.includes(message.type)) {
        subscription.callback(message);
        handled = true;
      }
    });

    if (!handled) {
      console.warn('WebSocket message received with no subscribers:', message.type);
    }
  }

  /**
   * Disconnect from WebSocket
   */
  disconnect(): void {
    if (this.client) {
      this.client.deactivate();
      this.client = null;
      this.userId = null;
      this.typedSubscriptions.clear();
      this.connectionListeners = [];
      this.subscription = null;
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
