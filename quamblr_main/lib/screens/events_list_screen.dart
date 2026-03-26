import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../services/event_service.dart';
import 'event_screen.dart';

class EventsListScreen extends ConsumerStatefulWidget {
  final int groupId;

  const EventsListScreen({super.key, required this.groupId});

  @override
  ConsumerState<EventsListScreen> createState() => _EventsListScreenState();
}

class _EventsListScreenState extends ConsumerState<EventsListScreen> {
  List<Map<String, dynamic>> _events = [];
  bool _isLoading = true;
  String? _error;
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final storage = ref.read(secureStorageProvider);
      _currentUserId = await storage.getUserId();

      // Fetch events for this group
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.dio.get(
        '/events/group/${widget.groupId}',
      );
      final list = response.data['events'] as List<dynamic>;
      setState(() {
        _events = list.cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to load events';
      });
    }
  }

  Future<void> _createEvent() async {
    final nameController = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Event'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: 'Event name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    try {
      final service = EventService(ref.read(apiClientProvider));
      await service.createEvent(
        groupId: widget.groupId,
        eventName: name,
      );
      await _load();
    } on DioException catch (e) {
      final responseData = e.response?.data;
      final msg = responseData is Map && responseData['error'] != null
          ? responseData['error'].toString()
          : 'Failed to create event';
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Events'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createEvent,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 8),
                      FilledButton(
                          onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : _events.isEmpty
                  ? const Center(
                      child: Text('No events yet. Tap + to create one.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _events.length,
                      itemBuilder: (context, index) {
                        final event = _events[index];
                        return Card(
                          child: ListTile(
                            title: Text(event['eventName'] as String),
                            subtitle: Text(
                                'Status: ${event['status'] ?? 'open'}'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              if (_currentUserId == null) return;
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => EventScreen(
                                  eventId: event['eventId'] as int,
                                  groupId: widget.groupId,
                                  currentUserId: _currentUserId!,
                                ),
                              ));
                            },
                          ),
                        );
                      },
                    ),
    );
  }
}
