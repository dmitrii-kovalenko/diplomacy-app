import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../config/app_config.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  
  late Dio dio;
  final FlutterSecureStorage storage = const FlutterSecureStorage();
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);
  
  Future<String?> getAccessToken() async {
    return await storage.read(key: 'access_token');
  }

  AuthService._internal() {
    dio = Dio(BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
    ));
    
    dio.interceptors.add(
      QueuedInterceptorsWrapper(
        onRequest: (options, handler) async {
          final accessToken = await storage.read(key: 'access_token');
          if (accessToken != null) {
            options.headers['Authorization'] = 'Bearer $accessToken';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 401) {
            final refreshToken = await storage.read(key: 'refresh_token');
            if (refreshToken != null) {
              try {
                final refreshResponse = await Dio().post(
                  '${AppConfig.baseUrl}/api/auth/refresh/',
                  data: {'refresh': refreshToken},
                );
                final newAccessToken = refreshResponse.data['access'];
                await storage.write(key: 'access_token', value: newAccessToken);
                
                e.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
                final retryResponse = await Dio().fetch(e.requestOptions);
                return handler.resolve(retryResponse);
              } catch (refreshError) {
                await logout();
              }
            } else {
              await logout();
            }
          }
          return handler.next(e);
        }
      )
    );
  }
  
  Future<void> _saveTokens(Map<String, dynamic> data) async {
    if (data.containsKey('access')) {
      await storage.write(key: 'access_token', value: data['access']);
    }
    if (data.containsKey('refresh')) {
      await storage.write(key: 'refresh_token', value: data['refresh']);
    }
  }

  Future<void> login(String email, String password) async {
    final response = await dio.post('/api/auth/login/', data: {
      'email': email,
      'password': password,
    });
    await _saveTokens(response.data as Map<String, dynamic>);
  }

  Future<void> register(String email, String password) async {
    await dio.post('/api/auth/register/', data: {
      'username': email,
      'email': email,
      'password': password,
    });
    await login(email, password);
  }

  Future<void> loginWithApple() async {
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );
    final response = await dio.post('/api/auth/oauth/apple/', data: {
      'id_token': credential.identityToken,
      'authorization_code': credential.authorizationCode,
    });
    await _saveTokens(response.data as Map<String, dynamic>);
  }

  Future<void> loginWithGoogle() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw Exception('Google login aborted');
    }
    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final response = await dio.post('/api/auth/oauth/google/', data: {
      'id_token': googleAuth.idToken,
      'access_token': googleAuth.accessToken,
    });
    await _saveTokens(response.data as Map<String, dynamic>);
  }

  Future<void> setNickname(String nickname) async {
    await dio.post('/api/me/nickname/', data: {'nickname': nickname});
  }

  Future<void> logout() async {
    await storage.delete(key: 'access_token');
    await storage.delete(key: 'refresh_token');
  }
  
  Future<Map<String, dynamic>> fetchMe() async {
    final response = await dio.get('/api/me/');
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteAccount() async {
    await dio.delete('/api/me/');
    await storage.delete(key: 'access_token');
    await storage.delete(key: 'refresh_token');
    await storage.delete(key: 'analytics_consent');
  }
}
