import 'api_client.dart';

class EventService {
  final ApiClient _client;

  EventService(this._client);

  Future<Map<String, dynamic>> createEvent({
    required int groupId,
    required String eventName,
  }) async {
    final response = await _client.dio.post('/events', data: {
      'groupId': groupId,
      'eventName': eventName,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> fetchEvent(int eventId) async {
    final response = await _client.dio.get('/events/$eventId');
    return response.data;
  }

  Future<void> patchEvent(int eventId, Map<String, dynamic> data) async {
    await _client.dio.patch('/events/$eventId', data: data);
  }

  Future<List<Map<String, dynamic>>> fetchGroupMembers(int groupId) async {
    final response = await _client.dio.get('/events/groups/$groupId/members');
    final members = response.data['members'] as List<dynamic>;
    return members.cast<Map<String, dynamic>>();
  }
}
