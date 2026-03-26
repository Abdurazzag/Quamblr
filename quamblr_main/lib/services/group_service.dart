import '../models/user.dart';
import 'api_client.dart';

class GroupService {
  final ApiClient _client;

  GroupService(this._client);

  // --- Core Group Methods ---

  Future<Map<String, dynamic>> createGroup({
    required String groupName,
    List<int> memberUserIds = const [],
  }) async {
    final response = await _client.dio.post(
      '/groups',
      data: {'groupName': groupName, 'memberUserIds': memberUserIds},
    );

    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<List<Map<String, dynamic>>> fetchGroups() async {
    final response = await _client.dio.get('/groups');
    final responseMap = Map<String, dynamic>.from(response.data as Map);
    final groups = responseMap['groups'];

    if (groups is! List) {
      return [];
    }

    return groups
        .whereType<Map>()
        .map((group) => Map<String, dynamic>.from(group))
        .toList();
  }

  Future<List<User>> fetchGroupMembers(int groupId) async {
    final response = await _client.dio.get('/groups/$groupId/members');
    final responseMap = Map<String, dynamic>.from(response.data as Map);
    final members = responseMap['members'];

    if (members is! List) {
      return [];
    }

    return members
        .whereType<Map>()
        .map((member) => User.fromJson(Map<String, dynamic>.from(member)))
        .toList();
  }

  Future<void> deleteGroup(int groupId) async {
    await _client.dio.delete('/groups/$groupId');
  }

  // --- Group Lists Methods ---

  Future<List<Map<String, dynamic>>> fetchGroupLists(int groupId) async {
    final response = await _client.dio.get('/groups/$groupId/lists');
    final lists = (response.data as Map)['lists'];

    if (lists is! List) return [];

    return lists
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> addGroupList(int groupId, String title) async {
    await _client.dio.post('/groups/$groupId/lists', data: {'title': title});
  }

  Future<void> deleteGroupList(int listId) async {
    await _client.dio.delete('/groups/lists/$listId');
  }

  // --- Group List Items Methods ---

  Future<List<Map<String, dynamic>>> fetchGroupListItems(int listId) async {
    final response = await _client.dio.get('/groups/lists/$listId/items');
    final items = (response.data as Map)['items'];

    if (items is! List) return [];

    return items
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> addGroupListItem(
    int listId,
    String content,
    int quantity,
    double price,
  ) async {
    await _client.dio.post(
      '/groups/lists/$listId/items',
      data: {'content': content, 'quantity': quantity, 'price': price},
    );
  }

  Future<void> toggleGroupListItem(int itemId, bool isDone) async {
    await _client.dio.patch(
      '/groups/lists/items/$itemId',
      data: {'isDone': isDone},
    );
  }

  Future<void> deleteGroupListItem(int itemId) async {
    await _client.dio.delete('/groups/lists/items/$itemId');
  }

  Future<void> toggleGroupItemClaim(int itemId) async {
    await _client.dio.post('/groups/lists/items/$itemId/claim');
  }

  Future<void> purchaseGroupItem(int itemId) async {
    await _client.dio.post('/groups/lists/items/$itemId/purchase');
  }
}
