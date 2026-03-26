import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/event_provider.dart';
import '../models/item_list.dart';

class EventScreen extends ConsumerStatefulWidget {
  final int eventId;
  final int groupId;
  final int currentUserId;

  const EventScreen({
    super.key,
    required this.eventId,
    required this.groupId,
    required this.currentUserId,
  });

  @override
  ConsumerState<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends ConsumerState<EventScreen> {
  late final _params =
      (eventId: widget.eventId, groupId: widget.groupId);

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(eventProvider(_params).notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(eventProvider(_params));

    return Scaffold(
      appBar: AppBar(
        title: Text(state.eventName ?? 'Event'),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (state.error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        state.error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  // Shopping List section
                  if (state.shoppingList == null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: OutlinedButton.icon(
                        onPressed: () => ref
                            .read(eventProvider(_params).notifier)
                            .createShoppingList(),
                        icon: const Icon(Icons.add_shopping_cart),
                        label: const Text('Create Shopping List'),
                      ),
                    )
                  else
                    _ShoppingListDropdown(
                      params: _params,
                      currentUserId: widget.currentUserId,
                    ),

                  const SizedBox(height: 8),

                  // Item List section
                  if (state.itemList == null)
                    OutlinedButton.icon(
                      onPressed: () => ref
                          .read(eventProvider(_params).notifier)
                          .createItemList(),
                      icon: const Icon(Icons.receipt_long),
                      label: const Text('Create Item List'),
                    )
                  else
                    _ItemListDropdown(
                      params: _params,
                      currentUserId: widget.currentUserId,
                    ),
                ],
              ),
            ),
    );
  }
}

// ─── Shopping List Dropdown ─────────────────────────────────────────

class _ShoppingListDropdown extends ConsumerStatefulWidget {
  final ({int eventId, int groupId}) params;
  final int currentUserId;

  const _ShoppingListDropdown({
    required this.params,
    required this.currentUserId,
  });

  @override
  ConsumerState<_ShoppingListDropdown> createState() =>
      _ShoppingListDropdownState();
}

class _ShoppingListDropdownState
    extends ConsumerState<_ShoppingListDropdown> {
  bool _expanded = true;
  final _nameController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');

  @override
  void dispose() {
    _nameController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  void _addItem() {
    final name = _nameController.text.trim();
    final qty = int.tryParse(_qtyController.text) ?? 0;
    if (name.isEmpty || qty <= 0) return;

    ref
        .read(eventProvider(widget.params).notifier)
        .addShoppingItem(name, qty);
    _nameController.clear();
    _qtyController.text = '1';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(eventProvider(widget.params));
    final sl = state.shoppingList!;
    final allPurchased =
        sl.items.isNotEmpty && sl.items.every((i) => i.purchased);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: _expanded,
        onExpansionChanged: (v) => setState(() => _expanded = v),
        title: Row(
          children: [
            const Text('Shopping List',
                style: TextStyle(fontWeight: FontWeight.w600)),
            if (allPurchased) ...[
              const SizedBox(width: 8),
              const Icon(Icons.check_circle, color: Colors.green, size: 20),
            ],
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      hintText: 'Item name',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _qtyController,
                    decoration: const InputDecoration(
                      hintText: 'Qty',
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _addItem,
                ),
              ],
            ),
          ),
          const Divider(),
          if (sl.items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No items yet', textAlign: TextAlign.center),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sl.items.length,
              itemBuilder: (context, index) {
                final item = sl.items[index];
                return ListTile(
                  title: Text(
                    '${item.name} x${item.quantity}',
                    style: TextStyle(
                      decoration: item.purchased
                          ? TextDecoration.lineThrough
                          : null,
                      color: item.purchased ? Colors.grey : null,
                    ),
                  ),
                  trailing: Checkbox(
                    value: item.purchased,
                    onChanged: (_) => ref
                        .read(eventProvider(widget.params).notifier)
                        .togglePurchased(index),
                  ),
                );
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── Item List Dropdown ─────────────────────────────────────────────

class _ItemListDropdown extends ConsumerStatefulWidget {
  final ({int eventId, int groupId}) params;
  final int currentUserId;

  const _ItemListDropdown({
    required this.params,
    required this.currentUserId,
  });

  @override
  ConsumerState<_ItemListDropdown> createState() =>
      _ItemListDropdownState();
}

class _ItemListDropdownState extends ConsumerState<_ItemListDropdown> {
  bool _expanded = true;
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  final Set<int> _selectedSplitWith = {};

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  void _addItem() {
    final name = _nameController.text.trim();
    final price = double.tryParse(_priceController.text) ?? 0;
    final qty = int.tryParse(_qtyController.text) ?? 0;
    if (name.isEmpty || price <= 0 || qty <= 0) return;

    final item = PurchasedItem(
      name: name,
      price: price,
      quantity: qty,
      boughtBy: widget.currentUserId,
      splitWith: _selectedSplitWith.toList(),
      claimedBy: [],
      pendingConfirm: _selectedSplitWith.toList(),
    );

    ref.read(eventProvider(widget.params).notifier).addPurchasedItem(item);
    _nameController.clear();
    _priceController.clear();
    _qtyController.text = '1';
    setState(() => _selectedSplitWith.clear());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(eventProvider(widget.params));
    final il = state.itemList!;
    final members = state.members;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: _expanded,
        onExpansionChanged: (v) => setState(() => _expanded = v),
        title: Row(
          children: [
            const Text('Item List',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(
              'Total: \$${il.totalCost.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
        children: [
          // Add item form
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    hintText: 'Item name',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _priceController,
                        decoration: const InputDecoration(
                          hintText: 'Price',
                          isDense: true,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _qtyController,
                        decoration: const InputDecoration(
                          hintText: 'Qty',
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('Split with:',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                Wrap(
                  spacing: 6,
                  children: members
                      .where(
                          (m) => m['userId'] != widget.currentUserId)
                      .map((m) {
                    final uid = m['userId'] as int;
                    final selected = _selectedSplitWith.contains(uid);
                    return FilterChip(
                      label: Text(m['username'] as String),
                      selected: selected,
                      onSelected: (v) {
                        setState(() {
                          if (v) {
                            _selectedSplitWith.add(uid);
                          } else {
                            _selectedSplitWith.remove(uid);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Item'),
                ),
              ],
            ),
          ),
          const Divider(),
          if (il.items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No items yet', textAlign: TextAlign.center),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: il.items.length,
              itemBuilder: (context, index) {
                final item = il.items[index];
                return _PurchasedItemTile(
                  item: item,
                  index: index,
                  currentUserId: widget.currentUserId,
                  state: state,
                  params: widget.params,
                );
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── Single Purchased Item Tile ─────────────────────────────────────

class _PurchasedItemTile extends ConsumerWidget {
  final PurchasedItem item;
  final int index;
  final int currentUserId;
  final EventState state;
  final ({int eventId, int groupId}) params;

  const _PurchasedItemTile({
    required this.item,
    required this.index,
    required this.currentUserId,
    required this.state,
    required this.params,
  });

  bool get _isSettled =>
      item.splitWith.isNotEmpty &&
      item.splitWith.every((uid) => item.claimedBy.contains(uid));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final splitNames =
        item.splitWith.map((id) => state.usernameForId(id)).join(', ');
    final boughtByName = state.usernameForId(item.boughtBy);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${item.name} x${item.quantity}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  '\$${(item.price * item.quantity).toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (_isSettled) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('Settled',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.green,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text('Bought by: $boughtByName',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            if (splitNames.isNotEmpty)
              Text('Split with: $splitNames',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),

            // Interaction for current user if in splitWith
            if (item.splitWith.contains(currentUserId) &&
                !item.claimedBy.contains(currentUserId) &&
                !item.pendingConfirm.contains(currentUserId))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: FilledButton.tonal(
                  onPressed: () => ref
                      .read(eventProvider(params).notifier)
                      .confirmPaid(index, currentUserId),
                  child: const Text('Confirm Paid'),
                ),
              ),

            if (item.pendingConfirm.contains(currentUserId) &&
                currentUserId != item.boughtBy)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Waiting for confirmation',
                    style: TextStyle(
                        color: Colors.orange, fontStyle: FontStyle.italic)),
              ),

            if (item.claimedBy.contains(currentUserId))
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Confirmed',
                    style: TextStyle(
                        color: Colors.green, fontWeight: FontWeight.w600)),
              ),

            // Approve buttons for the buyer
            if (currentUserId == item.boughtBy &&
                item.pendingConfirm.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Pending approvals:',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500)),
                    ...item.pendingConfirm.map((uid) {
                      return Row(
                        children: [
                          Text(state.usernameForId(uid)),
                          const Spacer(),
                          TextButton(
                            onPressed: () => ref
                                .read(eventProvider(params).notifier)
                                .approvePaid(index, uid),
                            child: const Text('Approve'),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
