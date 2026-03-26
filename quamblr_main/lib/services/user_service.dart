import '../models/user.dart';
import 'api_client.dart';

class UserService {
  final ApiClient _client;

  UserService(this._client);

  Future<List<User>> fetchUsers() async {
    final response = await _client.dio.get('/users');
    final responseMap = Map<String, dynamic>.from(response.data as Map);
    final users = responseMap['users'];

    if (users is! List) {
      return [];
    }

    return users
        .whereType<Map>()
        .map((user) => User.fromJson(Map<String, dynamic>.from(user)))
        .toList();
  }
}