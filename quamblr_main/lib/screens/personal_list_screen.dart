import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

class PersonalListScreen extends ConsumerStatefulWidget {
  final int listId;
  final String title;

  const PersonalListScreen({
    super.key,
    required this.listId,
    required this.title,
  });

  @override
  ConsumerState<PersonalListScreen> createState() => _PersonalListScreenState();
}

class _PersonalListScreenState extends ConsumerState<PersonalListScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    try {
      final items = await ref
          .read(personalServiceProvider)
          .fetchListItems(widget.listId);
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
              decoration: const InputDecoration(
                labelText: 'Item Name (e.g., Milk)',
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: qtyController,
                    decoration: const InputDecoration(labelText: 'Quantity'),
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
                    .read(personalServiceProvider)
                    .addListItem(widget.listId, content, qty, price);
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
    // Calculate total and remaining costs
    double totalCost = 0.0;
    double remainingCost = 0.0;

    for (var item in _items) {
      final qty = (item['quantity'] as num?)?.toInt() ?? 1;
      final price = (item['price'] as num?)?.toDouble() ?? 0.0;
      final isDone = item['isDone'] == 1;
      final itemTotal = qty * price;

      totalCost += itemTotal;
      if (!isDone) {
        remainingCost += itemTotal;
      }
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
                      'Estimated Total',
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
                        // Turns green if you've checked everything off!
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
          ? const Center(child: Text('No items yet. Add something!'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                final isDone = item['isDone'] == 1;
                final price = (item['price'] as num?)?.toDouble() ?? 0.0;
                final qty = (item['quantity'] as num?)?.toInt() ?? 1;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Checkbox(
                      value: isDone,
                      onChanged: (val) async {
                        // Optimistically update the UI so it feels instantly responsive
                        setState(() => _items[index]['isDone'] = val! ? 1 : 0);

                        // Send to backend and reload to ensure sort order is updated
                        await ref
                            .read(personalServiceProvider)
                            .toggleListItem(item['itemId'], val!);
                        _loadItems();
                      },
                    ),
                    title: Text(
                      item['content'],
                      style: TextStyle(
                        decoration: isDone ? TextDecoration.lineThrough : null,
                        color: isDone
                            ? Colors.grey
                            : null, // Grays out text when checked
                      ),
                    ),
                    subtitle: Text(
                      'Qty: $qty   •   £${price.toStringAsFixed(2)} each',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () async {
                        await ref
                            .read(personalServiceProvider)
                            .deleteListItem(item['itemId']);
                        _loadItems();
                      },
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
