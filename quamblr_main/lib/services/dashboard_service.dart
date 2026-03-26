import 'api_client.dart';

class DashboardService {
  final ApiClient _client;

  DashboardService(this._client);

  Future<Map<String, dynamic>> fetchDashboardData() async {
    final response = await _client.dio.get('/dashboard');
    return Map<String, dynamic>.from(response.data as Map);
  }
}
