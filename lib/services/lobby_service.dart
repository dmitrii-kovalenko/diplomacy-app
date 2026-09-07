import 'package:dio/dio.dart';
import 'auth_service.dart';

class LobbyService {
  final Dio dio;

  LobbyService() : dio = AuthService().dio;

  Future<Map<String, dynamic>> fetchLobby() async {
    final response = await dio.get('/api/lobby/');
    return response.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> fetchMaps() async {
    final response = await dio.get('/api/maps/');
    return response.data['maps'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> createGame(Map<String, dynamic> data) async {
    final response = await dio.post('/api/lobby/create/', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createSandbox(Map<String, dynamic> data) async {
    final response = await dio.post('/api/lobby/create-sandbox/', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> findGame(String shareId) async {
    final response = await dio.post('/api/lobby/find/', data: {'code': shareId});
    return response.data as Map<String, dynamic>;
  }

  Future<void> joinGame(String gameId, String empireId) async {
    await dio.post('/api/lobby/join/$gameId/$empireId/');
  }

  Future<void> leaveGame(String gameId) async {
    await dio.post('/api/lobby/leave/$gameId/');
  }

  Future<void> toggleMute(String gameId) async {
    await dio.post('/api/lobby/mute/$gameId/');
  }
}
