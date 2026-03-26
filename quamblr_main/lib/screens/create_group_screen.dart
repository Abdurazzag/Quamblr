import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import 'group_screen.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _groupNameController = TextEditingController();

  bool _isSubmitting = false;
  bool _isLoadingUsers = true;
  String? _error;
  String? _usersError;

  List<User> _users = const [];
  final Set<int> _selectedUserIds = <int>{};

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoadingUsers = true;
      _usersError = null;
    });

    try {
      final users = await ref.read(userServiceProvider).fetchUsers();

      if (!mounted) return;

      setState(() {
        _users = users;
        _isLoadingUsers = false;
      });
    } on DioException catch (e) {
      final responseData = e.response?.data;

      if (!mounted) return;

      setState(() {
        _usersError = responseData is Map && responseData['error'] != null
            ? responseData['error'].toString()
            : 'Failed to load users';
        _isLoadingUsers = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _usersError = 'Failed to load users';
        _isLoadingUsers = false;
      });
    }
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate() || _isSubmitting || _isLoadingUsers) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final response = await ref.read(groupServiceProvider).createGroup(
            groupName: _groupNameController.text.trim(),
            memberUserIds: _selectedUserIds.toList()..sort(),
          );

      final rawGroup = response['group'];
      final group = rawGroup is Map
          ? Map<String, dynamic>.from(rawGroup)
          : <String, dynamic>{};

      final groupId = group['groupId'] is num
          ? (group['groupId'] as num).toInt()
          : null;
      final groupName = group['groupName']?.toString() ??
          _groupNameController.text.trim();

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => GroupScreen(
            groupId: groupId,
            groupName: groupName,
          ),
        ),
      );
    } on DioException catch (e) {
      final responseData = e.response?.data;
      setState(() {
        _error = responseData is Map && responseData['error'] != null
            ? responseData['error'].toString()
            : 'Failed to create group';
      });
    } catch (_) {
      setState(() {
        _error = 'Failed to create group';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _toggleUser(bool? value, int userId) {
    setState(() {
      if (value == true) {
        _selectedUserIds.add(userId);
      } else {
        _selectedUserIds.remove(userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selectedUserIds.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Group'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _groupNameController,
                  decoration: const InputDecoration(
                    labelText: 'Group Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.groups_outlined),
                  ),
                  textInputAction: TextInputAction.done,
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) {
                      return 'Group name is required';
                    }
                    if (trimmed.length < 3) {
                      return 'Group name must be at least 3 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  'Add Users',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'You will be added automatically as the group owner.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Selected: $selectedCount',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton(
                      onPressed: _selectedUserIds.isEmpty
                          ? null
                          : () {
                              setState(() {
                                _selectedUserIds.clear();
                              });
                            },
                      child: const Text('Clear'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _isLoadingUsers
                        ? const Center(
                            child: CircularProgressIndicator(),
                          )
                        : _usersError != null
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _usersError!,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      OutlinedButton(
                                        onPressed: _loadUsers,
                                        child: const Text('Retry'),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : _users.isEmpty
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(20),
                                      child: Text(
                                        'No users available.',
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: _users.length,
                                    separatorBuilder: (_, __) =>
                                        const Divider(height: 1),
                                    itemBuilder: (context, index) {
                                      final user = _users[index];
                                      final isSelected = _selectedUserIds
                                          .contains(user.userId);

                                      return CheckboxListTile(
                                        value: isSelected,
                                        onChanged: (value) =>
                                            _toggleUser(value, user.userId),
                                        title: Text(user.username),
                                        subtitle: Text(
                                          'User ID: ${user.userId}',
                                        ),
                                        controlAffinity:
                                            ListTileControlAffinity.leading,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 4,
                                        ),
                                      );
                                    },
                                  ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed:
                        _isSubmitting || _isLoadingUsers ? null : _createGroup,
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Create Group'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}