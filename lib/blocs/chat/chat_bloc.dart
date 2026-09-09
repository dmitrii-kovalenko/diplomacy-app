import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../config/app_config.dart';
import '../../services/auth_service.dart';
import '../../services/e2ee_service.dart';
import '../../services/game_service.dart';

class ChatBloc extends ChangeNotifier {
  final String gameId;
  final AuthService _authService = AuthService();
  final E2EEService _e2eeService = E2EEService();
  final GameService _gameService = GameService();

  List<Map<String, dynamic>> conversations = [];
  Map<int, List<Map<String, dynamic>>> messages = {};

  // The game's other empires, for the new-conversation sheet. Fetched once
  // from /state/ rather than threaded through from GameScreen, since a
  // conversation can be opened, closed and reopened without rebuilding the
  // screen that owns the live board.
  List<Map<String, dynamic>> participants = [];
  String? myEmpireCode;
  // Distinct from `isLoading` (conversations): the new-conversation sheet
  // needs to tell "still fetching" from "fetched, and it came back empty"
  // from "the fetch failed" so it never renders a definitive claim on a
  // loading or broken condition.
  bool participantsLoading = true;
  bool participantsLoaded = false;

  final Map<int, WebSocketChannel> _channels = {};
  final Map<int, Timer> _reconnectTimers = {};
  final Map<int, Duration> _reconnectDelays = {};
  // Claims a conversation's connect slot for the span of the token lookup,
  // which awaits a secure-storage platform channel between the "no channel
  // yet" guard and the channel being stored — otherwise two overlapping
  // calls (e.g. fetchConversations firing for every open thread) both pass
  // the guard and open two sockets, orphaning the first.
  final Set<int> _connecting = {};
  bool isLoading = true;
  bool _disposed = false;

  // In-flight HTTP futures (participants, conversations, messages, send)
  // can resolve after the screen backs out and disposes the bloc;
  // ChangeNotifier throws if notifyListeners() runs after dispose().
  void _safeNotifyListeners() {
    if (!_disposed) notifyListeners();
  }

  ChatBloc(this.gameId) {
    _init();
  }

  Future<void> _init() async {
    await _e2eeService.init();
    await Future.wait([fetchConversations(), _fetchParticipants()]);
  }

  Future<void> _fetchParticipants() async {
    participantsLoading = true;
    _safeNotifyListeners();
    try {
      final state = await _gameService.fetchGameState(gameId);
      myEmpireCode = state['me']?['empire_code'] as String?;
      participants = List<Map<String, dynamic>>.from(
          state['participants'] as List? ?? []);
      participantsLoaded = true;
    } catch (e) {
      debugPrint('Failed to fetch game state for chat: $e');
      // Leave `participants` and `myEmpireCode` as they were — a transient
      // failure should not blank out data a previous attempt already got.
      participantsLoaded = false;
    } finally {
      participantsLoading = false;
      _safeNotifyListeners();
    }
  }

  /// Re-runs the participants fetch after a failure. The new-conversation
  /// sheet calls this when it opens and the previous attempt did not
  /// succeed, so a player is never stuck behind a one-shot failure for the
  /// life of the bloc.
  Future<void> retryParticipants() => _fetchParticipants();

  Map<String, dynamic>? _findConversation(int convId) {
    for (final c in conversations) {
      if (c['id'] == convId) return c;
    }
    return null;
  }

  void _connectWebSocket(int convId) async {
    if (_disposed) return;
    // A fresh, explicit connect attempt (from fetchConversations or our own
    // backoff timer) supersedes any pending retry for this conversation.
    _reconnectTimers.remove(convId)?.cancel();
    if (_channels.containsKey(convId)) return;

    if (_connecting.contains(convId)) return;
    _connecting.add(convId);

    final String? token;
    try {
      token = await _authService.getAccessToken();
    } finally {
      _connecting.remove(convId);
    }
    // Re-check after the await: another call may have claimed the slot and
    // already connected while we were waiting on secure storage.
    if (_disposed || _channels.containsKey(convId)) return;

    final url = Uri.parse('${AppConfig.wsUrl}/ws/chat/$convId/?token=$token');
    try {
      final channel = WebSocketChannel.connect(url);
      _channels[convId] = channel;
      // WebSocketChannel.connect returns synchronously, before the socket is
      // actually established (web_socket_channel's own doc on `ready`); only
      // reset the backoff once the connection is confirmed, not on every
      // attempt, or the ceiling is never reachable against a down server.
      var reconnectScheduled = false;
      channel.ready.then((_) {
        if (_disposed) return;
        _reconnectDelays[convId] = const Duration(seconds: 1);
      }).catchError((_) {
        // Surfaces again via onError/onDone below.
      });
      channel.stream.listen(
        (data) async {
          final payload = jsonDecode(data);
          if (payload['type'] == 'new_message') {
            final msg = Map<String, dynamic>.from(payload['message'] as Map);

            await fetchConversations();

            final conv = _findConversation(convId);
            if (conv != null && messages.containsKey(convId)) {
              await _decryptOne(msg, conv);
              if (!messages[convId]!.any((m) => m['id'] == msg['id'])) {
                messages[convId]!.add(msg);
                _safeNotifyListeners();
              }
            }
          }
        },
        onError: (e) {
          debugPrint('WS Error for $convId: $e');
          _channels.remove(convId);
          // onError is followed by onDone on the same broken socket
          // (cancelOnError defaults to false); only schedule once.
          if (!reconnectScheduled) {
            reconnectScheduled = true;
            _scheduleReconnect(convId);
          }
        },
        onDone: () {
          _channels.remove(convId);
          if (!reconnectScheduled) {
            reconnectScheduled = true;
            _scheduleReconnect(convId);
          }
        },
      );
    } catch (e) {
      debugPrint('WS connection failed for $convId: $e');
      _scheduleReconnect(convId);
    }
  }

  // Exponential backoff, 1s doubling to a 30s ceiling, so a dropped socket
  // recovers on its own instead of leaving the thread silently unreachable.
  // Backfills whatever arrived during the gap by re-running fetchMessages —
  // only for a thread the player currently has open — once the retry fires.
  void _scheduleReconnect(int convId) {
    if (_disposed) return;
    _reconnectTimers.remove(convId)?.cancel();
    final delay = _reconnectDelays[convId] ?? const Duration(seconds: 1);
    _reconnectTimers[convId] = Timer(delay, () {
      if (_disposed) return;
      _reconnectTimers.remove(convId);
      _connectWebSocket(convId);
      if (messages.containsKey(convId)) {
        fetchMessages(convId);
      }
    });
    final next = delay * 2;
    _reconnectDelays[convId] =
        next > const Duration(seconds: 30) ? const Duration(seconds: 30) : next;
  }

  Future<void> fetchConversations() async {
    try {
      final dio = _authService.dio;
      final response = await dio.get('/api/games/$gameId/conversations/');
      conversations =
          List<Map<String, dynamic>>.from(response.data['conversations']);

      for (var conv in conversations) {
        _connectWebSocket(conv['id'] as int);
      }

      isLoading = false;
      _safeNotifyListeners();
    } catch (e) {
      debugPrint('Failed to fetch conversations: $e');
      isLoading = false;
      _safeNotifyListeners();
    }
  }

  /// Returns true on success, mirroring `sendMessage`'s contract, so the
  /// sheet can leave itself open and surface an error instead of silently
  /// dropping the request.
  Future<bool> createConversation(List<String> empireCodes) async {
    try {
      final dio = _authService.dio;
      await dio.post('/api/games/$gameId/conversations/', data: {
        'empire_codes': empireCodes,
      });
      await fetchConversations();
      return true;
    } catch (e) {
      debugPrint('Failed to create conversation: $e');
      return false;
    }
  }

  Future<void> fetchMessages(int conversationId) async {
    try {
      final dio = _authService.dio;
      final response =
          await dio.get('/api/conversations/$conversationId/messages/');
      final conv = Map<String, dynamic>.from(response.data['conversation']);
      final msgs = List<Map<String, dynamic>>.from(response.data['messages']);

      for (final msg in msgs) {
        await _decryptOne(msg, conv);
      }

      messages[conversationId] = msgs;
      _safeNotifyListeners();
    } catch (e) {
      debugPrint('Failed to fetch messages: $e');
    }
  }

  // Ports chat.js's decryptMessages: for the other party's messages we use
  // the key snapshotted on the message itself (game/services/chat.py
  // serialize_message's `sender_public_key`), so a message stays readable
  // even after its sender later resets their key. For our own messages we
  // use the conversation's current peer key — ECDH is symmetric, so this is
  // only correct while the peer hasn't rotated; chat.js accepts the same
  // limitation rather than snapshotting a key for our own echoes.
  Future<void> _decryptOne(
      Map<String, dynamic> msg, Map<String, dynamic> conv) async {
    if (msg['scheme'] != 'e2ee') return;
    final isMine = msg['is_mine'] == true;
    final peerKey = _getOtherMemberKey(conv);
    final senderKey = msg['sender_public_key'] as String?;
    final pub = isMine
        ? peerKey
        : ((senderKey != null && senderKey.isNotEmpty) ? senderKey : peerKey);
    if (pub == null) {
      msg['_locked'] = true;
      return;
    }
    final text = await _e2eeService.decryptMessage(
      msg['ciphertext'] as String,
      msg['iv'] as String,
      pub,
    );
    if (text == null) {
      msg['_locked'] = true;
    } else {
      msg['text'] = text;
    }
  }

  String? _getOtherMemberKey(Map<String, dynamic> conv) {
    if (conv['encryption'] == 'e2ee') {
      // Since it's E2EE, there are exactly 2 members. ECDH derives the same
      // shared secret from either side, so grabbing the member whose key
      // isn't ours is enough — we don't need to know which empire is "them".
      final myPubKey = _e2eeService.myPublicKeyBase64;
      for (var m in (conv['members'] as List? ?? [])) {
        if (m['has_key'] == true && m['public_key'] != myPubKey) {
          return m['public_key'] as String?;
        }
      }
    }
    return null;
  }

  /// Returns true on success. The caller (MessagesScreen) restores the
  /// composer text and shows an error toast on false.
  Future<bool> sendMessage(int conversationId, String text) async {
    final conv = _findConversation(conversationId);
    if (conv == null) return false;
    final isE2ee = conv['encryption'] == 'e2ee';

    // Plaintext is the guaranteed fallback — the server Fernet-encrypts it
    // at rest — and is only overwritten once encryption actually succeeds.
    // A request must never leave with neither `text` nor `ciphertext`+`iv`:
    // that would sidestep the ENC:/E2E: invariant instead of satisfying it.
    Map<String, dynamic> data = {'text': text};
    if (isE2ee) {
      final otherMemberKey = _getOtherMemberKey(conv);
      if (otherMemberKey != null) {
        try {
          final encrypted =
              await _e2eeService.encryptMessage(text, otherMemberKey);
          data = {'ciphertext': encrypted['ciphertext'], 'iv': encrypted['iv']};
        } catch (e) {
          debugPrint('Encryption failed, sending server-side encrypted: $e');
        }
      }
    }
    assert(
      (data['text'] is String && (data['text'] as String).isNotEmpty) ||
          (data['ciphertext'] != null && data['iv'] != null),
      'chat payload must carry text or a full ciphertext+iv pair',
    );

    try {
      final dio = _authService.dio;
      final response = await dio
          .post('/api/conversations/$conversationId/messages/', data: data);

      final newMsg = Map<String, dynamic>.from(response.data['message']);
      if (newMsg['scheme'] == 'e2ee') {
        newMsg['text'] = text; // We already know the plaintext we just sent.
      }

      messages[conversationId] ??= [];
      if (!messages[conversationId]!.any((m) => m['id'] == newMsg['id'])) {
        messages[conversationId]!.add(newMsg);
        _safeNotifyListeners();
      }
      return true;
    } catch (e) {
      debugPrint('Failed to send message: $e');
      return false;
    }
  }

  Future<void> markAsRead(int conversationId) async {
    try {
      final dio = _authService.dio;
      await dio.post('/api/conversations/$conversationId/read/');
      // Zero the badge locally rather than round-tripping fetchConversations
      // again — the server has nothing new to tell us about this thread.
      final conv = _findConversation(conversationId);
      if (conv != null) {
        conv['unread'] = 0;
        _safeNotifyListeners();
      }
    } catch (e) {
      debugPrint('Failed to mark read: $e');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    for (final timer in _reconnectTimers.values) {
      timer.cancel();
    }
    _reconnectTimers.clear();
    for (var channel in _channels.values) {
      channel.sink.close();
    }
    super.dispose();
  }
}
