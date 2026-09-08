/// App configuration for environment-aware settings.
class AppConfig {
  static const String appName = 'Diplomacy';
  static const String appVersion = '1.0.0';

  // Backend API base URL
  // For production, override via --dart-define=BASE_URL=https://your-server.com
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'https://game.dmitrii-kovalenko.xyz',
  );

  // WebSocket base URL (derived from baseUrl)
  static String get wsUrl {
    return baseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
  }

  // API endpoints
  static const String apiPrefix = '/api';
  static const String wsPrefix = '/ws';

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // WebSocket reconnect delay
  static const Duration wsReconnectDelay = Duration(seconds: 3);
}
