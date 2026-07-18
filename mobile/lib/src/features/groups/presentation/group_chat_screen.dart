import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';

enum _MessageKind { me, member, announcement }

class _ChatMessage {
  final String id;
  final String senderName;
  final String text;
  final _MessageKind kind;
  final DateTime timestamp;

  const _ChatMessage({
    required this.id,
    required this.senderName,
    required this.text,
    required this.kind,
    required this.timestamp,
  });
}

/// Group chat is UI-only for now — there's no chat backend yet.
/// State lives entirely in memory and resets on leaving the screen.
class GroupChatScreen extends StatefulWidget {
  final String groupId;

  const GroupChatScreen({super.key, required this.groupId});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _isOtherTyping = false;

  late final List<_ChatMessage> _messages = [
    _ChatMessage(
      id: '1',
      senderName: 'Admin',
      text: 'Welcome to the group! Contributions are due every cycle — check Home for your next date.',
      kind: _MessageKind.announcement,
      timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
    ),
    _ChatMessage(
      id: '2',
      senderName: 'Amara',
      text: 'Just sent my contribution ✅',
      kind: _MessageKind.member,
      timestamp: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    _ChatMessage(
      id: '3',
      senderName: 'Tunde',
      text: 'Nice one! Same here.',
      kind: _MessageKind.member,
      timestamp: DateTime.now().subtract(const Duration(hours: 4, minutes: 40)),
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(id: '${_messages.length}', senderName: 'You', text: text, kind: _MessageKind.me, timestamp: DateTime.now()));
      _controller.clear();
      _isOtherTyping = true;
    });
    _scrollToBottom();

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _isOtherTyping = false;
        _messages.add(_ChatMessage(
          id: '${_messages.length}',
          senderName: 'Amara',
          text: 'Got it, thanks! 🙌',
          kind: _MessageKind.member,
          timestamp: DateTime.now(),
        ));
      });
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
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
            Text('Group Chat', style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) => _MessageBubble(message: _messages[index]),
              ),
            ),
            if (_isOtherTyping)
              Padding(
                padding: const EdgeInsets.only(left: 20, bottom: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Amara is typing…', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textMuted, fontStyle: FontStyle.italic)),
                ),
              ),
            _Composer(controller: _controller, onSend: _send),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    if (message.kind == _MessageKind.announcement) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.paleGreen, borderRadius: BorderRadius.circular(AppRadius.md)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.campaign_rounded, color: AppColors.accentGreen, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Admin announcement', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.accentGreen)),
                  const SizedBox(height: 4),
                  Text(message.text, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textPrimary, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final isMe = message.kind == _MessageKind.me;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
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
            if (!isMe) Text(message.senderName, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.accentGreen)),
            if (!isMe) const SizedBox(height: 2),
            Text(message.text, style: GoogleFonts.plusJakartaSans(fontSize: 13.5, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text(formatTime(message.timestamp), style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const _Composer({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12, MediaQuery.of(context).padding.bottom + 10),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Image sharing coming soon'), backgroundColor: AppColors.darkGreen),
              );
            },
            icon: const Icon(Icons.image_outlined, color: AppColors.textSecondary),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Message the group…',
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
            child: IconButton(onPressed: onSend, icon: const Icon(Icons.send_rounded, color: AppColors.darkGreen, size: 20)),
          ),
        ],
      ),
    );
  }
}
