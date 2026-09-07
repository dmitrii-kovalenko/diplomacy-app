import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../config/app_config.dart';
import '../../models/game_model.dart';
import '../../services/lobby_service.dart';

class LobbyBloc extends ChangeNotifier {
  final LobbyService _lobbyService = LobbyService();
  final _storage = const FlutterSecureStorage();
  WebSocketChannel? _channel;
  bool _isDisposed = false;

  bool isLoading = false;
  String? error;

  List<GameModel> yourTurn = [];
  List<GameModel> waiting = [];
  List<GameModel> openLobbies = [];
  List<GameModel> surrendered = [];
  List<GameModel> observed = [];
  List<GameModel> completed = [];

  LobbyBloc() {
    refreshLobby();
    _initWebSocket();
  }

  Future<void> _initWebSocket() async {
    if (_isDisposed) return;
    
    final token = await _storage.read(key: 'access_token');
    if (token == null) return;

    // Connect to WebSocket using the token in query parameter
    final wsUrl = Uri.parse('${AppConfig.wsUrl}/ws/lobby/?token=$token');
    
    try {
      _channel = WebSocketChannel.connect(wsUrl);
      _channel!.stream.listen((message) {
        if (_isDisposed) return;
        try {
          final data = jsonDecode(message);
          if (data['type'] == 'lobby_changed') {
            refreshLobby();
          }
        } catch (e) {
          debugPrint('WS message parse error: $e');
        }
      }, onError: (e) {
        debugPrint('WS error: $e');
        _reconnect();
      }, onDone: () {
        debugPrint('WS closed');
        _reconnect();
      });
    } catch (e) {
      debugPrint('WS connection failed: $e');
      _reconnect();
    }
  }

  void _reconnect() {
    if (_isDisposed) return;
    Future.delayed(const Duration(seconds: 3), () {
      if (!_isDisposed) {
        _initWebSocket();
      }
    });
  }

  Future<void> refreshLobby() async {
    if (_isDisposed) return;
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final data = await _lobbyService.fetchLobby();
      if (_isDisposed) return;
      
      yourTurn = _parseGameList(data['your_turn']);
      waiting = _parseGameList(data['waiting']);
      openLobbies = _parseGameList(data['open_lobbies']);
      surrendered = _parseGameList(data['surrendered']);
      observed = _parseGameList(data['observed']);
      completed = _parseGameList(data['completed']);
    } catch (e) {
      if (_isDisposed) return;
      error = e.toString();
    } finally {
      if (!_isDisposed) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  List<GameModel> _parseGameList(dynamic jsonList) {
    if (jsonList == null || jsonList is! List) return [];
    return jsonList.map((e) => GameModel.fromJson(e)).toList();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _channel?.sink.close();
    super.dispose();
  }
}
