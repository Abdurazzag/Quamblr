import 'api_client.dart';

class AuthService {
  final ApiClient _client;

  AuthService(this._client);

  Future<Map<String, dynamic>> register({
    required String username,
    required String password,
  }) async {
    final response = await _client.dio.post('/auth/register', data: {
      'username': username,
      'password': password,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final response = await _client.dio.post('/auth/login', data: {
      'username': username,
      'password': password,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> refresh(String refreshToken) async {
    final response = await _client.dio.post('/auth/refresh', data: {
      'refreshToken': refreshToken,
    });
    return response.data;
  }

  Future<void> logout(String refreshToken) async {
    await _client.dio.post('/auth/logout', data: {
      'refreshToken': refreshToken,
    });
  }
}
