import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../config/app_config.dart';
import '../../services/auth_service.dart';
import '../../services/e2ee_service.dart';

class ChatBloc extends ChangeNotifier {
  final String gameId;
  final AuthService _authService = AuthService();
  final E2EEService _e2eeService = E2EEService();
  
  List<Map<String, dynamic>> conversations = [];
  Map<int, List<Map<String, dynamic>>> messages = {};
  
  final Map<int, WebSocketChannel> _channels = {};
  bool isLoading = true;

  ChatBloc(this.gameId) {
    _init();
  }

  Future<void> _init() async {
    await _e2eeService.init();
    await fetchConversations();
  }

  void _connectWebSocket(int convId) async {
    if (_channels.containsKey(convId)) return;
    
    final token = await _authService.getAccessToken();
    final url = Uri.parse('${AppConfig.wsUrl}/ws/chat/$convId/?token=$token');
    try {
      final channel = WebSocketChannel.connect(url);
      _channels[convId] = channel;
      channel.stream.listen(
        (data) async {
          final payload = jsonDecode(data);
          if (payload['type'] == 'new_message') {
            final msg = payload['message'];
            
            await fetchConversations(); 

            if (messages.containsKey(convId)) {
              final conv = conversations.firstWhere((c) => c['id'] == convId);
              if (msg['scheme'] == 'e2ee') {
                final otherMemberKey = _getOtherMemberKey(conv);
                if (otherMemberKey != null) {
                  msg['text'] = await _e2eeService.decryptMessage(
                    msg['ciphertext'],
                    msg['iv'],
                    otherMemberKey,
                  );
                }
              }
              if (!messages[convId]!.any((m) => m['id'] == msg['id'])) {
                messages[convId]!.add(msg);
                notifyListeners();
              }
            }
          }
        },
        onError: (e) => debugPrint('WS Error for $convId: $e'),
        onDone: () {
          _channels.remove(convId);
        },
      );
    } catch (e) {
      debugPrint('WS connection failed for $convId: $e');
    }
  }

  Future<void> fetchConversations() async {
    try {
      final dio = _authService.dio;
      final response = await dio.get('/api/games/$gameId/conversations/');
      conversations = List<Map<String, dynamic>>.from(response.data['conversations']);
      
      for (var conv in conversations) {
        _connectWebSocket(conv['id']);
      }
      
      isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to fetch conversations: $e');
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createConversation(List<String> empireCodes) async {
    try {
      final dio = _authService.dio;
      await dio.post('/api/games/$gameId/conversations/', data: {
        'empire_codes': empireCodes,
      });
      await fetchConversations();
    } catch (e) {
      debugPrint('Failed to create conversation: $e');
    }
  }

  Future<void> fetchMessages(int conversationId) async {
    try {
      final dio = _authService.dio;
      final response = await dio.get('/api/conversations/$conversationId/messages/');
      final conv = response.data['conversation'];
      final msgs = List<Map<String, dynamic>>.from(response.data['messages']);

      final otherMemberKey = _getOtherMemberKey(conv);

      for (var msg in msgs) {
        if (msg['scheme'] == 'e2ee' && otherMemberKey != null) {
          msg['text'] = await _e2eeService.decryptMessage(
            msg['ciphertext'],
            msg['iv'],
            otherMemberKey,
          );
        }
      }

      messages[conversationId] = msgs;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to fetch messages: $e');
    }
  }

  String? _getOtherMemberKey(Map<String, dynamic> conv) {
    if (conv['encryption'] == 'e2ee') {
       // Since it's E2EE, there are exactly 2 members.
       // The public key we want is the one that belongs to the other person.
       // Without `is_mine` on the member, we can just grab both and one will be our own.
       // But wait, the ECDH derivation works exactly the same if we use the other person's key.
       // Let's find the first member whose public key is NOT our public key.
       final myPubKey = _e2eeService.myPublicKeyBase64; // Need to expose this
       for (var m in conv['members']) {
         if (m['has_key'] && m['public_key'] != myPubKey) {
           return m['public_key'];
         }
       }
    }
    return null;
  }

  Future<void> sendMessage(int conversationId, String text) async {
    try {
      // Find the conversation
      final conv = conversations.firstWhere((c) => c['id'] == conversationId);
      final isE2ee = conv['encryption'] == 'e2ee';
      
      Map<String, dynamic> data = {};
      if (isE2ee) {
        final otherMemberKey = _getOtherMemberKey(conv);
        if (otherMemberKey != null) {
          final encrypted = await _e2eeService.encryptMessage(text, otherMemberKey);
          data = encrypted; // Contains ciphertext and iv
        }
      } else {
        data = {'text': text};
      }

      final dio = _authService.dio;
      final response = await dio.post('/api/conversations/$conversationId/messages/', data: data);
      
      // The response returns the serialized message. Decrypt it if necessary for local display.
      final newMsg = response.data['message'];
      if (newMsg['scheme'] == 'e2ee') {
        newMsg['text'] = text; // We already know the plaintext
      }
      
      messages[conversationId] ??= [];
      if (!messages[conversationId]!.any((m) => m['id'] == newMsg['id'])) {
        messages[conversationId]!.add(newMsg);
        notifyListeners();
      }
      
    } catch (e) {
      debugPrint('Failed to send message: $e');
    }
  }

  Future<void> markAsRead(int conversationId) async {
    try {
      final dio = _authService.dio;
      await dio.post('/api/conversations/$conversationId/read/');
    } catch (e) {
      debugPrint('Failed to mark read: $e');
    }
  }

  @override
  void dispose() {
    for (var channel in _channels.values) {
      channel.sink.close();
    }
    super.dispose();
  }
}
