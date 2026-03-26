import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user.dart';
import '../providers/auth_provider.dart';
import 'events_list_screen.dart';
import 'group_lists_screen.dart';
import 'group_workspace_screen.dart';

const double _groupPageImageAspectRatio = 1137 / 2048;
const String _groupPageImageAsset = 'assets/images/group_page_background.png';
const List<String> _spriteAssets = [
  'assets/images/Sprite1.png',
  'assets/images/Sprite2.png',
  'assets/images/Sprite3.png',
  'assets/images/Sprite4.png',
  'assets/images/Sprite5.png',
  'assets/images/Sprite6.png',
];

class GroupScreen extends ConsumerStatefulWidget {
  final int? groupId;
  final String groupName;

  const GroupScreen({
    super.key,
    required this.groupName,
    this.groupId,
  });

  @override
  ConsumerState<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends ConsumerState<GroupScreen> {
  static const List<String> _buttonTitles = [
    'Scan barcode',
    'Group lists',
    'Group events',
  ];

  bool _isDeleting = false;
  bool _isLoadingMembers = false;
  String? _error;
  List<User> _members = const [];
  List<_SpritePlacement> _memberPlacements = const [];

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  void _openScreen(String title) {
    if (title == 'Group events' && widget.groupId != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EventsListScreen(groupId: widget.groupId!),
        ),
      );
      return;
    }

    if (title == 'Group lists' && widget.groupId != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GroupListsScreen(
            groupId: widget.groupId!,
            groupName: widget.groupName,
          ),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GroupWorkspaceScreen(title: title),
      ),
    );
  }

  Future<void> _loadMembers() async {
    final groupId = widget.groupId;
    if (groupId == null) {
      return;
    }

    setState(() {
      _isLoadingMembers = true;
      _error = null;
    });

    try {
      final members = await ref.read(groupServiceProvider).fetchGroupMembers(
            groupId,
          );

      if (!mounted) return;

      setState(() {
        _members = members;
        _memberPlacements = _generateSpritePlacements(members.length);
        _isLoadingMembers = false;
      });
    } on DioException catch (e) {
      final responseData = e.response?.data;

      if (!mounted) return;

      setState(() {
        _error = responseData is Map && responseData['error'] != null
            ? responseData['error'].toString()
            : 'Failed to load group members';
        _isLoadingMembers = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'Failed to load group members';
        _isLoadingMembers = false;
      });
    }
  }

  List<_SpritePlacement> _generateSpritePlacements(int count) {
    if (count <= 0) {
      return const [];
    }

    final random = Random();

    const minLeft = 0.08;
    const maxLeft = 0.78;
    const minTop = 0.42;
    const maxTop = 0.78;

    return List.generate(count, (_) {
      final left = minLeft + (random.nextDouble() * (maxLeft - minLeft));
      final top = minTop + (random.nextDouble() * (maxTop - minTop));

      return _SpritePlacement(
        leftFactor: left,
        topFactor: top,
      );
    });
  }

  String _spriteAssetForUser(User user) {
    final spriteIndex = (user.userId - 1) % _spriteAssets.length;
    return _spriteAssets[spriteIndex];
  }

  Future<void> _deleteGroup() async {
    final groupId = widget.groupId;
    if (groupId == null || _isDeleting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Group'),
        content: Text('Delete "${widget.groupName}" permanently?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isDeleting = true;
      _error = null;
    });

    try {
      await ref.read(groupServiceProvider).deleteGroup(groupId);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      final responseData = e.response?.data;

      if (!mounted) return;

      setState(() {
        _error = responseData is Map && responseData['error'] != null
            ? responseData['error'].toString()
            : 'Failed to delete group';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'Failed to delete group';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  Widget _buildGroupScene() {
    return AspectRatio(
      aspectRatio: _groupPageImageAspectRatio,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final spriteSize =
              (constraints.maxWidth * 0.12).clamp(46.0, 82.0).toDouble();
          final labelWidth =
              (constraints.maxWidth * 0.18).clamp(72.0, 120.0).toDouble();
          final spriteBlockHeight = spriteSize + 28;
          final availableWidth = max(0.0, constraints.maxWidth - labelWidth);
          final availableHeight = max(
            0.0,
            constraints.maxHeight - spriteBlockHeight,
          );

          return ClipRect(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    _groupPageImageAsset,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    filterQuality: FilterQuality.none,
                  ),
                ),
                for (var index = 0;
                    index < _members.length && index < _memberPlacements.length;
                    index++)
                  Positioned(
                    left: _memberPlacements[index].leftFactor * availableWidth,
                    top: _memberPlacements[index].topFactor * availableHeight,
                    child: _MemberSprite(
                      username: _members[index].username,
                      spriteAssetPath: _spriteAssetForUser(_members[index]),
                      spriteSize: spriteSize,
                      labelWidth: labelWidth,
                    ),
                  ),
                if (_isLoadingMembers)
                  const Positioned.fill(
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Row(
        children: [
          for (var index = 0; index < _buttonTitles.length; index++) ...[
            Expanded(
              child: SizedBox(
                height: 132,
                child: _GroupActionButton(
                  title: _buttonTitles[index],
                  onPressed: () => _openScreen(_buttonTitles[index]),
                ),
              ),
            ),
            if (index != _buttonTitles.length - 1) const SizedBox(width: 16),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canDelete = widget.groupId != null && !_isDeleting;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).maybePop();
          },
        ),
        title: Text(widget.groupName),
        actions: [
          if (widget.groupId != null)
            IconButton(
              tooltip: 'Delete group',
              onPressed: canDelete ? _deleteGroup : null,
              icon: _isDeleting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: _buildGroupScene(),
                      ),
                      const Spacer(),
                      _buildBottomButtons(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MemberSprite extends StatelessWidget {
  final String username;
  final String spriteAssetPath;
  final double spriteSize;
  final double labelWidth;

  const _MemberSprite({
    required this.username,
    required this.spriteAssetPath,
    required this.spriteSize,
    required this.labelWidth,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: labelWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: spriteSize,
            height: spriteSize,
            child: Image.asset(
              spriteAssetPath,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.none,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.62),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupActionButton extends StatelessWidget {
  final String title;
  final VoidCallback onPressed;

  const _GroupActionButton({
    required this.title,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        side: const BorderSide(color: Colors.black87, width: 1.6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        foregroundColor: Colors.black87,
      ),
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SpritePlacement {
  final double leftFactor;
  final double topFactor;

  const _SpritePlacement({
    required this.leftFactor,
    required this.topFactor,
  });
}