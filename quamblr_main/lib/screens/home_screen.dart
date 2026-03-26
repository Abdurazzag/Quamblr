import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import 'create_group_screen.dart';
import 'group_screen.dart';
import 'splash_screen.dart';
import 'personal_list_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isLoading = true;
  String? _error;

  String _username = 'Student';
  List<Map<String, dynamic>> _groups = const [];
  Map<String, dynamic>? _dashboardData;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadAllData();
  }

  // Decodes the JWT token to extract the username
  Future<void> _loadUserData() async {
    try {
      final token = await ref.read(secureStorageProvider).getAccessToken();
      if (token != null) {
        final parts = token.split('.');
        if (parts.length == 3) {
          final payload = utf8.decode(
            base64Url.decode(base64Url.normalize(parts[1])),
          );
          final payloadMap = json.decode(payload);

          if (mounted && payloadMap['username'] != null) {
            setState(() {
              _username = payloadMap['username'];
            });
          }
        }
      }
    } catch (_) {
      // Keep default 'Student' if decoding fails
    }
  }

  // Fetch both Groups and Dashboard data simultaneously
  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Run both API calls in parallel
      final results = await Future.wait([
        ref.read(groupServiceProvider).fetchGroups(),
        ref.read(dashboardServiceProvider).fetchDashboardData(),
      ]);

      if (!mounted) return;

      setState(() {
        _groups = results[0] as List<Map<String, dynamic>>;
        _dashboardData = results[1] as Map<String, dynamic>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Failed to load dashboard data';
        _isLoading = false;
      });
    }
  }

  Future<void> _openCreateGroupScreen() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CreateGroupScreen()));
    if (!mounted) return;
    await _loadAllData();
  }

  void _openGroup(Map<String, dynamic> group) {
    final groupId = group['groupId'] is num
        ? (group['groupId'] as num).toInt()
        : null;
    final groupName = group['groupName']?.toString() ?? 'Unnamed Group';

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GroupScreen(groupId: groupId, groupName: groupName),
      ),
    );
  }

  // --- Add/Delete Item Methods ---

  Future<void> _showAddItemDialog(String type) async {
    final controller = TextEditingController();
    final isList = type == 'list';

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add ${isList ? 'List' : 'Activity'}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter ${isList ? 'list name' : 'activity'}...',
          ),
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
                try {
                  if (isList) {
                    await ref.read(personalServiceProvider).addList(text);
                  } else {
                    await ref.read(personalServiceProvider).addActivity(text);
                  }
                  _loadAllData(); // Refresh the dashboard
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to add $type')),
                    );
                  }
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteItem(String type, int id) async {
    try {
      if (type == 'list') {
        await ref.read(personalServiceProvider).deleteList(id);
      } else {
        await ref.read(personalServiceProvider).deleteActivity(id);
      }
      _loadAllData(); // Refresh the dashboard
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to delete item')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (!context.mounted) return;

              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const SplashScreen()),
                (_) => false,
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAllData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _buildErrorState()
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  // User Greeting
                  Text(
                    'Hello, $_username!',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Financial Summary Card
                  _buildFinancialSummary(context),
                  const SizedBox(height: 32),

                  // Groups Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Your Groups',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('New'),
                        onPressed: _openCreateGroupScreen,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Groups List
                  if (_groups.isEmpty)
                    _buildEmptyState(
                      'No groups yet.',
                      'Create one to start collaborating!',
                      Icons.group_off_outlined,
                    )
                  else
                    ..._groups.map((group) => _buildGroupCard(group, context)),

                  const SizedBox(height: 32),

                  // Recent Activity Section
                  const Text(
                    'Recent Activity',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  _buildRecentActivityList(context),
                  const SizedBox(height: 32),

                  // Split View: Lists & Activities
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildPersonalListsSection(context)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildPersonalActivitiesSection(context)),
                    ],
                  ),

                  const SizedBox(height: 40),
                ],
              ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _loadAllData, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialSummary(BuildContext context) {
    final owedAmt = (_dashboardData?['financial']?['owed'] ?? 0).toDouble();
    final oweAmt = (_dashboardData?['financial']?['owe'] ?? 0).toDouble();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.arrow_upward,
                        size: 16,
                        color: Colors.green.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'You are owed',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '£${owedAmt.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Container(width: 1, height: 50, color: Colors.grey.shade300),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.arrow_downward,
                          size: 16,
                          color: Colors.red.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'You owe',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '£${oweAmt.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupCard(Map<String, dynamic> group, BuildContext context) {
    final groupName = group['groupName']?.toString() ?? 'Unnamed Group';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openGroup(group),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  groupName.isNotEmpty ? groupName[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  groupName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivityList(BuildContext context) {
    final recent = _dashboardData?['recent'] as List? ?? [];

    if (recent.isEmpty) {
      return const Text(
        'No recent activity.',
        style: TextStyle(color: Colors.grey),
      );
    }

    return Column(
      children: recent.map((item) {
        final isExpense = item['type'] == 'expense';
        final title = item['title'] ?? 'Unknown';
        final meta = item['meta']?.toString() ?? '';

        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: isExpense
                ? Colors.blue.shade50
                : Colors.orange.shade50,
            child: Icon(
              isExpense ? Icons.receipt_long : Icons.event,
              color: isExpense ? Colors.blue.shade700 : Colors.orange.shade700,
              size: 20,
            ),
          ),
          title: Text(title),
          subtitle: Text(isExpense ? 'Amount: £$meta' : 'Status: $meta'),
        );
      }).toList(),
    );
  }

  Widget _buildPersonalListsSection(BuildContext context) {
    final lists = _dashboardData?['lists'] as List? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Personal Lists',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 20),
              onPressed: () => _showAddItemDialog('list'),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (lists.isEmpty)
          const Text(
            'No lists',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          )
        else
          Card(
            elevation: 0,
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withOpacity(0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: lists.map((item) {
                  // Wrapped the MiniListItem in an InkWell to handle navigation
                  return InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PersonalListScreen(
                            listId: item['listId'],
                            title: item['title'] ?? 'Untitled',
                          ),
                        ),
                      );
                    },
                    child: _MiniListItem(
                      icon: Icons.list_alt,
                      text: item['title'] ?? 'Untitled',
                      onDelete: () => _deleteItem('list', item['listId']),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPersonalActivitiesSection(BuildContext context) {
    final activities = _dashboardData?['activities'] as List? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Activities',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 20),
              onPressed: () => _showAddItemDialog('activity'),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (activities.isEmpty)
          const Text(
            'No activities',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          )
        else
          Card(
            elevation: 0,
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withOpacity(0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: activities.map((item) {
                  return _MiniListItem(
                    icon: Icons.task_alt,
                    text: item['title'] ?? 'Untitled',
                    onDelete: () => _deleteItem('activity', item['activityId']),
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }
}

class _MiniListItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onDelete;

  const _MiniListItem({
    required this.icon,
    required this.text,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          InkWell(
            onTap: onDelete,
            child: Icon(Icons.close, size: 16, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
