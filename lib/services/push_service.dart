import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../main.dart';
import '../screens/game/game_screen.dart';
import '../blocs/chat/chat_bloc.dart';
import '../screens/chat/messages_screen.dart';
import 'auth_service.dart';

class PushService {
  static final PushService _instance = PushService._internal();
  factory PushService() => _instance;
  PushService._internal();

  final _messaging = FirebaseMessaging.instance;
  final _authService = AuthService();

  Future<void> init() async {
    // 1. Request permissions
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      String? token = await _messaging.getToken();
      if (token != null) _registerTokenWithBackend(token);
      _messaging.onTokenRefresh.listen(_registerTokenWithBackend);

      // Foreground message listener
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        // You could show a local snackbar here using a global navigator key
        // or just rely on badges.
      });

      // Background tap listener
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
    }
  }

  Future<void> handleInitialMessage() async {
    RemoteMessage? initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessage(initialMessage);
    }
  }

  void _handleMessage(RemoteMessage message) {
    final data = message.data;
    
    if (data.containsKey('conversation_id')) {
      final convId = int.tryParse(data['conversation_id'].toString());
      final gameId = data['game_id']?.toString() ?? 'unknown';
      if (convId != null) {
        final bloc = ChatBloc(gameId);
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => MessagesScreen(bloc: bloc, conversationId: convId),
          ),
        );
      }
    } else if (data.containsKey('game_id')) {
      final gameId = data['game_id'].toString();
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => GameScreen(gameId: gameId),
        ),
      );
    }
  }

  Future<void> _registerTokenWithBackend(String token) async {
    try {
      await _authService.dio.post(
        '/api/me/push-token/',
        data: {'token': token},
      );
    } catch (e) {
      // Handle error or token refresh failure silently
    }
  }
}
