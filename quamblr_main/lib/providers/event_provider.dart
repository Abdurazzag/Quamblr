import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/shopping_list.dart';
import '../models/item_list.dart';
import '../services/event_service.dart';
import 'auth_provider.dart';

class EventState {
  final bool isLoading;
  final String? error;
  final String? eventName;
  final ShoppingList? shoppingList;
  final ItemList? itemList;
  final List<Map<String, dynamic>> members;

  const EventState({
    this.isLoading = false,
    this.error,
    this.eventName,
    this.shoppingList,
    this.itemList,
    this.members = const [],
  });

  EventState copyWith({
    bool? isLoading,
    String? error,
    String? eventName,
    ShoppingList? shoppingList,
    ItemList? itemList,
    List<Map<String, dynamic>>? members,
    bool clearShoppingList = false,
    bool clearItemList = false,
    bool clearError = false,
  }) {
    return EventState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      eventName: eventName ?? this.eventName,
      shoppingList:
          clearShoppingList ? null : (shoppingList ?? this.shoppingList),
      itemList: clearItemList ? null : (itemList ?? this.itemList),
      members: members ?? this.members,
    );
  }

  String usernameForId(int userId) {
    for (final m in members) {
      if (m['userId'] == userId) return m['username'] as String;
    }
    return 'Unknown';
  }
}

class EventNotifier extends StateNotifier<EventState> {
  final EventService _service;
  final int eventId;
  final int groupId;

  EventNotifier(this._service, this.eventId, this.groupId)
      : super(const EventState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final results = await Future.wait([
        _service.fetchEvent(eventId),
        _service.fetchGroupMembers(groupId),
      ]);

      final eventData = results[0] as Map<String, dynamic>;
      final membersData = results[1] as List<Map<String, dynamic>>;
      final event = eventData['event'] as Map<String, dynamic>;

      ShoppingList? sl;
      if (event['shoppingList'] != null) {
        sl = ShoppingList.fromJson(
            Map<String, dynamic>.from(event['shoppingList']));
      }

      ItemList? il;
      if (event['itemList'] != null) {
        il = ItemList.fromJson(Map<String, dynamic>.from(event['itemList']));
      }

      state = state.copyWith(
        isLoading: false,
        eventName: event['eventName'] as String,
        shoppingList: sl,
        itemList: il,
        members: membersData,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to load event');
    }
  }

  Future<void> createShoppingList() async {
    final sl = ShoppingList();
    state = state.copyWith(shoppingList: sl);
    try {
      await _service.patchEvent(eventId, {'shoppingList': sl.toJson()});
    } catch (e) {
      state = state.copyWith(error: 'Failed to save shopping list');
    }
  }

  Future<void> createItemList() async {
    final il = ItemList();
    state = state.copyWith(itemList: il);
    try {
      await _service.patchEvent(eventId, {'itemList': il.toJson()});
    } catch (e) {
      state = state.copyWith(error: 'Failed to save item list');
    }
  }

  Future<void> addShoppingItem(String name, int quantity) async {
    final sl = state.shoppingList;
    if (sl == null) return;
    sl.items.add(ShoppingItem(name: name, quantity: quantity));
    state = state.copyWith(shoppingList: sl, clearError: true);
    try {
      await _service.patchEvent(eventId, {'shoppingList': sl.toJson()});
    } catch (e) {
      state = state.copyWith(error: 'Failed to save');
    }
  }

  Future<void> togglePurchased(int index) async {
    final sl = state.shoppingList;
    if (sl == null || index >= sl.items.length) return;
    sl.items[index].purchased = !sl.items[index].purchased;
    state = state.copyWith(shoppingList: sl, clearError: true);
    try {
      await _service.patchEvent(eventId, {'shoppingList': sl.toJson()});
    } catch (e) {
      state = state.copyWith(error: 'Failed to save');
    }
  }

  Future<void> addPurchasedItem(PurchasedItem item) async {
    final il = state.itemList;
    if (il == null) return;
    il.items.add(item);
    il.totalCost =
        il.items.fold(0.0, (sum, i) => sum + (i.price * i.quantity));
    state = state.copyWith(itemList: il, clearError: true);
    try {
      await _service.patchEvent(eventId, {'itemList': il.toJson()});
    } catch (e) {
      state = state.copyWith(error: 'Failed to save');
    }
  }

  Future<void> confirmPaid(int itemIndex, int userId) async {
    final il = state.itemList;
    if (il == null || itemIndex >= il.items.length) return;
    final item = il.items[itemIndex];
    if (!item.pendingConfirm.contains(userId)) {
      item.pendingConfirm.add(userId);
    }
    state = state.copyWith(itemList: il, clearError: true);
    try {
      await _service.patchEvent(eventId, {'itemList': il.toJson()});
    } catch (e) {
      state = state.copyWith(error: 'Failed to save');
    }
  }

  Future<void> approvePaid(int itemIndex, int userId) async {
    final il = state.itemList;
    if (il == null || itemIndex >= il.items.length) return;
    final item = il.items[itemIndex];
    item.pendingConfirm.remove(userId);
    if (!item.claimedBy.contains(userId)) {
      item.claimedBy.add(userId);
    }
    state = state.copyWith(itemList: il, clearError: true);
    try {
      await _service.patchEvent(eventId, {'itemList': il.toJson()});
    } catch (e) {
      state = state.copyWith(error: 'Failed to save');
    }
  }
}

final eventServiceProvider = Provider((ref) {
  return EventService(ref.read(apiClientProvider));
});

final eventProvider = StateNotifierProvider.autoDispose
    .family<EventNotifier, EventState, ({int eventId, int groupId})>(
        (ref, params) {
  final service = ref.read(eventServiceProvider);
  return EventNotifier(service, params.eventId, params.groupId);
});
