import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import 'dart:convert';

// --- SCREEN 1: Overview of all lists in a group ---
class GroupListsScreen extends ConsumerStatefulWidget {
  final int groupId;
  final String groupName;

  const GroupListsScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  ConsumerState<GroupListsScreen> createState() => _GroupListsScreenState();
}

class _GroupListsScreenState extends ConsumerState<GroupListsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _lists = [];

  @override
  void initState() {
    super.initState();
    _loadLists();
  }

  Future<void> _loadLists() async {
    try {
      final lists = await ref
          .read(groupServiceProvider)
          .fetchGroupLists(widget.groupId);
      if (mounted) {
        setState(() {
          _lists = lists;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showAddListDialog() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Group List'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g., Weekly Groceries'),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                Navigator.pop(context);
                await ref
                    .read(groupServiceProvider)
                    .addGroupList(widget.groupId, text);
                _loadLists();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.groupName} Lists')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _lists.isEmpty
          ? const Center(child: Text('No group lists yet.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _lists.length,
              itemBuilder: (context, index) {
                final list = _lists[index];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.list_alt),
                    title: Text(list['title'] ?? 'Untitled'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () async {
                        await ref
                            .read(groupServiceProvider)
                            .deleteGroupList(list['listId']);
                        _loadLists();
                      },
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GroupListItemsScreen(
                            listId: list['listId'],
                            title: list['title'] ?? 'Untitled',
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddListDialog,
        icon: const Icon(Icons.add),
        label: const Text('New List'),
      ),
    );
  }
}

// --- SCREEN 2: The detailed items inside a specific group list ---
class GroupListItemsScreen extends ConsumerStatefulWidget {
  final int listId;
  final String title;

  const GroupListItemsScreen({
    super.key,
    required this.listId,
    required this.title,
  });

  @override
  ConsumerState<GroupListItemsScreen> createState() =>
      _GroupListItemsScreenState();
}

class _GroupListItemsScreenState extends ConsumerState<GroupListItemsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _items = [];
  String _currentUsername = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadItems();
  }

  Future<void> _loadUserData() async {
    try {
      final token = await ref.read(secureStorageProvider).getAccessToken();
      if (token != null) {
        final parts = token.split('.');
        if (parts.length == 3) {
          final payload = json.decode(
            utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
          );
          if (mounted && payload['username'] != null) {
            setState(() => _currentUsername = payload['username']);
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _loadItems() async {
    try {
      final items = await ref
          .read(groupServiceProvider)
          .fetchGroupListItems(widget.listId);
      if (mounted) {
        setState(() {
          _items = items;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showAddItemDialog() async {
    final contentController = TextEditingController();
    final qtyController = TextEditingController(text: '1');
    final priceController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: contentController,
              decoration: const InputDecoration(labelText: 'Item Name'),
              autofocus: true,
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: qtyController,
                    decoration: const InputDecoration(labelText: 'Qty'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: priceController,
                    decoration: const InputDecoration(labelText: 'Price (£)'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final content = contentController.text.trim();
              final qty = int.tryParse(qtyController.text) ?? 1;
              final price = double.tryParse(priceController.text) ?? 0.0;
              if (content.isNotEmpty) {
                Navigator.pop(context);
                await ref
                    .read(groupServiceProvider)
                    .addGroupListItem(widget.listId, content, qty, price);
                _loadItems();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double totalCost = 0.0;
    double remainingCost = 0.0;

    for (var item in _items) {
      final qty = (item['quantity'] as num?)?.toInt() ?? 1;
      final price = (item['price'] as num?)?.toDouble() ?? 0.0;
      final isDone = item['isDone'] == 1;
      final itemTotal = qty * price;

      totalCost += itemTotal;
      if (!isDone) remainingCost += itemTotal;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 8.0,
            ),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      '£${totalCost.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Remaining',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      '£${remainingCost.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: remainingCost > 0
                            ? Theme.of(context).colorScheme.primary
                            : Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? const Center(child: Text('No items yet.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                final isDone = item['isDone'] == 1;
                final price = (item['price'] as num?)?.toDouble() ?? 0.0;
                final qty = (item['quantity'] as num?)?.toInt() ?? 1;
                final purchaser =
                    item['purchaserName']?.toString() ?? 'Someone';

                final claimersList = item['claimers'] as List? ?? [];
                final isClaimedByMe = claimersList.any(
                  (c) => c['username'] == _currentUsername,
                );

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- TOP ROW: Details & Delete ---
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['content'],
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      decoration: isDone
                                          ? TextDecoration.lineThrough
                                          : null,
                                      color: isDone ? Colors.grey : null,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Qty: $qty   •   £${price.toStringAsFixed(2)} each',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              onPressed: () async {
                                await ref
                                    .read(groupServiceProvider)
                                    .deleteGroupListItem(item['itemId']);
                                _loadItems();
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // --- BOTTOM ROW: Claims & Purchase logic ---
                        if (isDone)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 16,
                                  color: Colors.green.shade700,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Purchased by $purchaser',
                                  style: TextStyle(
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else ...[
                          // Claimers Chips
                          if (claimersList.isNotEmpty)
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: claimersList
                                  .map(
                                    (c) => Chip(
                                      visualDensity: VisualDensity.compact,
                                      labelStyle: const TextStyle(fontSize: 12),
                                      label: Text(c['username']),
                                      backgroundColor: Theme.of(context)
                                          .colorScheme
                                          .primaryContainer
                                          .withOpacity(0.5),
                                      side: BorderSide.none,
                                    ),
                                  )
                                  .toList(),
                            )
                          else
                            const Text(
                              'Unclaimed',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                fontStyle: FontStyle.italic,
                              ),
                            ),

                          const SizedBox(height: 12),
                          Row(
                            children: [
                              OutlinedButton.icon(
                                onPressed: () async {
                                  await ref
                                      .read(groupServiceProvider)
                                      .toggleGroupItemClaim(item['itemId']);
                                  _loadItems();
                                },
                                icon: Icon(
                                  isClaimedByMe
                                      ? Icons.back_hand
                                      : Icons.pan_tool_alt,
                                ),
                                label: Text(
                                  isClaimedByMe ? 'Unclaim' : 'Claim',
                                ),
                              ),
                              const Spacer(),
                              FilledButton.icon(
                                onPressed: () async {
                                  await ref
                                      .read(groupServiceProvider)
                                      .purchaseGroupItem(item['itemId']);
                                  _loadItems();
                                },
                                icon: const Icon(Icons.shopping_bag),
                                label: const Text('Purchased'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddItemDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
      ),
    );
  }
}
