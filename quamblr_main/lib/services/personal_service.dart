import 'api_client.dart';

class PersonalService {
  final ApiClient _client;

  PersonalService(this._client);

  // --- Activities & Base Lists ---
  Future<void> addActivity(String title) async {
    await _client.dio.post('/personal/activities', data: {'title': title});
  }

  Future<void> deleteActivity(int id) async {
    await _client.dio.delete('/personal/activities/$id');
  }

  Future<void> addList(String title) async {
    await _client.dio.post('/personal/lists', data: {'title': title});
  }

  Future<void> deleteList(int id) async {
    await _client.dio.delete('/personal/lists/$id');
  }

  // --- List Items ---
  Future<List<Map<String, dynamic>>> fetchListItems(int listId) async {
    final response = await _client.dio.get('/personal/lists/$listId/items');
    final responseMap = Map<String, dynamic>.from(response.data as Map);
    final items = responseMap['items'];
    if (items is! List) return [];
    return items
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> addListItem(
    int listId,
    String content,
    int quantity,
    double price,
  ) async {
    await _client.dio.post(
      '/personal/lists/$listId/items',
      data: {'content': content, 'quantity': quantity, 'price': price},
    );
  }

  Future<void> toggleListItem(int itemId, bool isDone) async {
    await _client.dio.patch(
      '/personal/lists/items/$itemId',
      data: {'isDone': isDone},
    );
  }

  Future<void> deleteListItem(int itemId) async {
    await _client.dio.delete('/personal/lists/items/$itemId');
  }
}
