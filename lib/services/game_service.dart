import 'package:dio/dio.dart';
import 'auth_service.dart';

class GameService {
  final Dio dio = AuthService().dio;

  Future<void> submitOrder(String gameId, Map<String, dynamic> data) async {
    try {
      await dio.post('/api/games/$gameId/orders/', data: data);
    } on DioException catch (e) {
      // Surface the server's own message (game/api/orders.py returns
      // {"error": "..."} on both validation failures and the blanket
      // exception handler) rather than letting a raw DioException reach the
      // caller, so OrderBloc has something worth putting in a toast.
      final body = e.response?.data;
      final serverMessage = body is Map ? body['error']?.toString() : null;
      throw Exception(serverMessage ?? 'Could not submit the order.');
    }
  }

  Future<void> cancelOrder(String orderId) async {
    await dio.delete('/api/orders/$orderId/');
  }

  Future<void> toggleReady(String gameId, bool isReady, bool isDelayed) async {
    await dio.post('/api/games/$gameId/ready/', data: {
      'ready': isReady,
      'delayed': isDelayed,
    });
  }

  Future<void> surrender(String gameId) async {
    await dio.post('/api/games/$gameId/surrender/');
  }

  // The endpoint wraps the phase in an envelope ({"phase": {...} | null}) —
  // unwrap it here so callers get the phase itself, matching what the Mini
  // App's `r.phase` does (assets/game/orders_ui.js loadHistoryPhase).
  Future<Map<String, dynamic>?> fetchHistory(String gameId, int offset) async {
    final response = await dio.get('/api/games/$gameId/history/', queryParameters: {'offset': offset});
    final data = response.data as Map<String, dynamic>;
    return data['phase'] as Map<String, dynamic>?;
  }

  Future<Map<String, dynamic>> fetchGameState(String gameId) async {
    final response = await dio.get('/api/games/$gameId/state/');
    return response.data as Map<String, dynamic>;
  }

  Future<String> fetchSvg(String url) async {
    final response = await dio.get(url);
    return response.data.toString();
  }

  Future<void> proposeDraw(String gameId) async {
    await dio.post('/api/games/$gameId/propose-draw/');
  }

  Future<void> drawVote(String gameId, bool accept) async {
    await dio.post('/api/games/$gameId/draw-vote/', data: {'accept': accept});
  }

  Future<Map<String, dynamic>> getTournament(String id) async {
    final response = await dio.get('/api/tournament/$id/');
    return response.data as Map<String, dynamic>;
  }

  Future<void> registerForTournament(String id) async {
    await dio.post('/api/tournament/$id/register/');
  }

  Future<Map<String, dynamic>> getGamePreview(String gameId) async {
    final response = await dio.get('/api/games/$gameId/preview/');
    return response.data as Map<String, dynamic>;
  }
}
