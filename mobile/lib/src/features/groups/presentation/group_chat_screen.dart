import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../auth/data/user_repository.dart';
import '../data/chat_message.dart';
import '../data/chat_repository.dart';
import '../data/group_models.dart';
import '../data/group_repository.dart';

/// Real-time group chat over the backend's WebSocket
/// (`WS /groups/{id}/ws?token=...`), seeded with history from
/// `GET /groups/{id}/chat`. System messages (member joined, contribution
/// posted, payout sent, etc.) arrive over the same socket with `is_system: true`.
class GroupChatScreen extends ConsumerStatefulWidget {
  final String groupId;

  const GroupChatScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends ConsumerState<GroupChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  List<ChatMessage> _messages = [];
  Map<String, GroupMember> _membersById = {};
  String? _currentUserId;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;

  bool _isLoadingHistory = true;
  String? _loadError;
  String? _connectionError;
  String? _editingMessageId;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _channel?.sink.close();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _currentUserId = ref.read(currentUserProvider)?.id;
    try {
      final results = await Future.wait([
        ref.read(chatRepositoryProvider).getHistory(widget.groupId),
        ref.read(groupRepositoryProvider).getMembers(widget.groupId),
      ]);
      if (!mounted) return;
      setState(() {
        _messages = results[0] as List<ChatMessage>;
        _membersById = {for (final m in results[1] as List<GroupMember>) m.userId: m};
        _isLoadingHistory = false;
      });
      _scrollToBottom(animate: false);
      await _connect();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingHistory = false;
        _loadError = e.message;
      });
    }
  }

  Future<void> _connect() async {
    setState(() => _connectionError = null);
    try {
      final channel = await ref.read(chatRepositoryProvider).connect(widget.groupId);
      _channel = channel;
      _subscription = channel.stream.listen(
        _handleIncoming,
        onError: (_) {
          if (mounted) setState(() => _connectionError = 'Connection lost. Tap to reconnect.');
        },
        onDone: () {
          if (mounted) setState(() => _connectionError = 'Disconnected. Tap to reconnect.');
        },
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _connectionError = e.message);
    }
  }

  // Broadcasts are action-tagged: {"action": "new_message", "message": {...}},
  // {"action": "message_edited", "message": {...}}, {"action": "message_deleted", "message_id": "..."}.
  void _handleIncoming(dynamic raw) {
    try {
      final json = jsonDecode(raw as String) as Map<String, dynamic>;
      final action = json['action']?.toString();

      switch (action) {
        case 'message_deleted':
          final id = json['message_id']?.toString();
          if (id == null || !mounted) return;
          setState(() {
            _messages = [
              for (final m in _messages)
                if (m.id == id) m.copyWith(message: 'This message was deleted.', isDeleted: true) else m,
            ];
          });
          return;
        case 'new_message':
        case 'message_edited':
          final data = json['message'];
          if (data is! Map<String, dynamic> || !mounted) return;
          final message = ChatMessage.fromJson(data);
          setState(() {
            final exists = _messages.any((m) => m.id == message.id);
            _messages = exists
                ? [for (final m in _messages) if (m.id == message.id) message else m]
                : [..._messages, message];
          });
          _scrollToBottom();
          return;
        default:
          // No action tag at all — tolerate a raw ChatMessage object too,
          // in case an older backend build is ever in front of us.
          final message = ChatMessage.fromJson(json);
          if (!mounted) return;
          setState(() => _messages = [..._messages, message]);
          _scrollToBottom();
      }
    } catch (_) {
      // Ignore malformed frames rather than crash the chat.
    }
  }

  /// Sends a new message, or — if [_editingMessageId] is set — submits an
  /// edit to that message instead. Either way we wait for the broadcast
  /// echo to actually update `_messages` rather than updating optimistically.
  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    if (_channel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not connected. Tap the banner to reconnect.', style: TextStyle(color: Colors.white)), backgroundColor: AppColors.darkGreen),
      );
      return;
    }

    final editingId = _editingMessageId;
    if (editingId != null) {
      _channel!.sink.add(jsonEncode({'action': 'edit', 'message_id': editingId, 'message': text}));
      setState(() => _editingMessageId = null);
    } else {
      _channel!.sink.add(jsonEncode({'action': 'send', 'message': text}));
    }
    _controller.clear();
  }

  void _startEdit(ChatMessage message) {
    setState(() {
      _editingMessageId = message.id;
      _controller.text = message.message;
      _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingMessageId = null;
      _controller.clear();
    });
  }

  Future<void> _confirmDelete(ChatMessage message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this message?'),
        content: const Text('This replaces it with "This message was deleted" for everyone in the group.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || _channel == null) return;
    _channel!.sink.add(jsonEncode({'action': 'delete', 'message_id': message.id}));
  }

  void _showMessageActions(ChatMessage message) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: AppColors.textPrimary),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(sheetContext);
                _startEdit(message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
              title: const Text('Delete', style: TextStyle(color: AppColors.danger)),
              onTap: () {
                Navigator.pop(sheetContext);
                _confirmDelete(message);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animate) {
        _scrollController.animateTo(target, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: Row(
          children: [
            const CircleAvatar(radius: 16, backgroundColor: AppColors.paleGreen, child: Icon(Icons.groups_rounded, color: AppColors.accentGreen, size: 16)),
            const SizedBox(width: 10),
            Text('Group Chat', style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_connectionError != null)
              GestureDetector(
                onTap: _connect,
                child: Container(
                  width: double.infinity,
                  color: AppColors.warningPale,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Text(
                    _connectionError!,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.warning),
                  ),
                ),
              ),
            Expanded(child: _buildBody()),
            _Composer(
              controller: _controller,
              onSend: _send,
              isEditing: _editingMessageId != null,
              onCancelEdit: _cancelEdit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoadingHistory) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (context, index) => const Padding(padding: EdgeInsets.only(bottom: 10), child: SkeletonListTile()),
      );
    }

    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_loadError!, style: TextStyle(fontFamily: 'PlusJakartaSans', color: AppColors.textSecondary), textAlign: TextAlign.center),
        ),
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Text(
          'No messages yet. Say hello 👋',
          style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, color: AppColors.textMuted),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isMe = message.senderId != null && message.senderId == _currentUserId;
        return _MessageBubble(
          message: message,
          isMe: isMe,
          senderName: message.senderId != null ? _membersById[message.senderId]?.fullName : null,
          onLongPress: (isMe && !message.isSystem && !message.isDeleted) ? () => _showMessageActions(message) : null,
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final String? senderName;
  final VoidCallback? onLongPress;

  const _MessageBubble({required this.message, required this.isMe, required this.senderName, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    if (message.isSystem) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.paleGreen, borderRadius: BorderRadius.circular(AppRadius.md)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline_rounded, color: AppColors.accentGreen, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message.message, style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, color: AppColors.textPrimary, height: 1.4)),
            ),
          ],
        ),
      );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: BoxDecoration(
          color: isMe ? AppColors.brandGreen : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          boxShadow: cardShadow(opacity: 0.03),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe) Text(senderName ?? 'Member', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.accentGreen)),
            if (!isMe) const SizedBox(height: 2),
            Text(
              message.message,
              style: TextStyle(fontFamily: 'PlusJakartaSans', 
                fontSize: 13.5,
                color: message.isDeleted ? AppColors.textMuted : AppColors.textPrimary,
                fontStyle: message.isDeleted ? FontStyle.italic : FontStyle.normal,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(formatTime(message.createdAt), style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 10, color: AppColors.textMuted)),
                if (message.isEdited && !message.isDeleted) ...[
                  const SizedBox(width: 4),
                  Text('· edited', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 10, color: AppColors.textMuted, fontStyle: FontStyle.italic)),
                ],
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isEditing;
  final VoidCallback onCancelEdit;

  const _Composer({
    required this.controller,
    required this.onSend,
    this.isEditing = false,
    required this.onCancelEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isEditing)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.paleGreen,
              child: Row(
                children: [
                  const Icon(Icons.edit_outlined, size: 14, color: AppColors.accentGreen),
                  const SizedBox(width: 6),
                  Text(
                    'Editing message',
                    style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.accentGreen),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: onCancelEdit,
                    child: const Icon(Icons.close_rounded, size: 16, color: AppColors.accentGreen),
                  ),
                ],
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(12, 10, 12, MediaQuery.of(context).padding.bottom + 10),
            child: Row(
              children: [
                IconButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Image sharing coming soon', style: TextStyle(color: Colors.white)), backgroundColor: AppColors.darkGreen),
                    );
                  },
                  icon: const Icon(Icons.image_outlined, color: AppColors.textSecondary),
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 4,
                    onSubmitted: (_) => onSend(),
                    style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: isEditing ? 'Edit your message…' : 'Message the group…',
                      hintStyle: const TextStyle(color: AppColors.hint, fontSize: 13),
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: const BoxDecoration(color: AppColors.brandGreen, shape: BoxShape.circle),
                  child: IconButton(
                    onPressed: onSend,
                    icon: Icon(isEditing ? Icons.check_rounded : Icons.send_rounded, color: AppColors.darkGreen, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
