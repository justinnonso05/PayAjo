import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../../core/widgets/status_pill.dart';
import '../../../routing/app_router.dart';
import '../../auth/data/user_repository.dart';
import '../data/group_models.dart';
import '../data/group_repository.dart';
import 'widgets/edit_group_sheet.dart';
import 'widgets/send_invite_sheet.dart';

class GroupDetailsScreen extends ConsumerStatefulWidget {
  final String groupId;

  const GroupDetailsScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends ConsumerState<GroupDetailsScreen> {
  GroupResponse? _group;
  List<GroupMember> _members = [];
  List<PendingMembership> _pendingMembers = [];
  bool _isLoading = true;
  bool _isLoadingPending = false;
  bool _isBusy = false;
  String? _error;

  bool get _isCurrentUserAdmin {
    final currentUserId = ref.read(currentUserProvider)?.id;
    return currentUserId != null && _group?.adminUserId == currentUserId;
  }

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
      final repo = ref.read(groupRepositoryProvider);
      final results = await Future.wait([repo.getGroup(widget.groupId), repo.getMembers(widget.groupId)]);
      setState(() {
        _group = results[0] as GroupResponse;
        _members = results[1] as List<GroupMember>;
        _isLoading = false;
      });
      if (_isCurrentUserAdmin) _loadPendingMembers();
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPendingMembers() async {
    setState(() => _isLoadingPending = true);
    try {
      final pending = await ref.read(groupRepositoryProvider).getPendingMembers(widget.groupId);
      setState(() {
        _pendingMembers = pending;
        _isLoadingPending = false;
      });
    } on ApiException {
      setState(() => _isLoadingPending = false);
    }
  }

  Future<void> _approveMember(PendingMembership pending) async {
    setState(() => _isBusy = true);
    try {
      await ref.read(groupRepositoryProvider).approveMember(widget.groupId, pending.userId);
      await Future.wait([_loadPendingMembers(), _refreshMembers()]);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Member approved'), backgroundColor: AppColors.darkGreen));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.darkGreen));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _refreshMembers() async {
    final members = await ref.read(groupRepositoryProvider).getMembers(widget.groupId);
    if (mounted) setState(() => _members = members);
  }

  Future<void> _startGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Start this group?'),
        content: const Text('This locks in the payout rotation order and begins the first contribution cycle. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Start Group')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isBusy = true);
    try {
      final updated = await ref.read(groupRepositoryProvider).startGroup(widget.groupId, randomize: true);
      setState(() => _group = updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Group started!'), backgroundColor: AppColors.darkGreen));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.darkGreen));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _rotateInviteCode() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Generate a new invite code?'),
        content: const Text('The current code will stop working immediately.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Generate')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isBusy = true);
    try {
      final updated = await ref.read(groupRepositoryProvider).rotateInviteCode(widget.groupId);
      setState(() => _group = updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('New invite code generated'), backgroundColor: AppColors.darkGreen));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.darkGreen));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _sendInvite() async {
    final sent = await SendInviteSheet.show(context, widget.groupId);
    if (sent != true || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invite sent'), backgroundColor: AppColors.darkGreen));
  }

  Future<void> _editGroup() async {
    final updated = await EditGroupSheet.show(context, _group!);
    if (updated == null) return;
    setState(() => _group = updated);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Group updated'), backgroundColor: AppColors.darkGreen));
  }

  void _copyInviteCode() {
    final code = _group?.inviteCode;
    if (code == null) return;
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invite code copied'), backgroundColor: AppColors.darkGreen));
  }

  void _shareInviteLink() {
    final code = _group?.inviteCode;
    if (code == null) return;
    Clipboard.setData(ClipboardData(text: 'Join my AjoPay group with code $code'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invite message copied — paste it anywhere to share'), backgroundColor: AppColors.darkGreen),
    );
  }

  void _showMembers() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Members (${_members.length})', style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  itemCount: _members.length,
                  separatorBuilder: (context, index) => Divider(color: Colors.grey[100]),
                  itemBuilder: (context, index) {
                    final member = _members[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: const BoxDecoration(color: AppColors.paleGreen, shape: BoxShape.circle),
                            child: Center(
                              child: Text(
                                member.firstName.isNotEmpty ? member.firstName[0].toUpperCase() : '?',
                                style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, color: AppColors.accentGreen),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(member.fullName, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                Text('@${member.username}', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textMuted)),
                              ],
                            ),
                          ),
                          if (member.isAdmin)
                            const StatusPill(label: 'Admin', tone: PillTone.info)
                          else
                            StatusPill(
                              label: member.status == 'active' ? 'Active' : member.status,
                              tone: member.status == 'active' ? PillTone.success : PillTone.warning,
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _leaveGroup(bool isAdmin) async {
    if (isAdmin) {
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Transfer ownership first'),
          content: const Text('As the admin, you need to transfer group ownership to another member before you can leave.'),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Got it'))],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Leave this group?'),
        content: const Text("You'll lose access to its contributions and chat."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Leave')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Leaving a group is coming soon'), backgroundColor: AppColors.darkGreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: Text('Group Details', style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Padding(padding: EdgeInsets.all(24), child: SkeletonCard(height: 400))
            : _error != null
                ? Center(child: Text(_error!, style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary)))
                : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final group = _group!;
    final admin = _members.where((m) => m.isAdmin).toList();
    final isCurrentUserAdmin = _isCurrentUserAdmin;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(group.name, style: GoogleFonts.spaceGrotesk(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            ),
            if (isCurrentUserAdmin)
              IconButton(onPressed: _isBusy ? null : _editGroup, icon: const Icon(Icons.edit_outlined, color: AppColors.textSecondary)),
          ],
        ),
        Row(
          children: [
            StatusPill(label: group.status, tone: group.status == 'active' ? PillTone.success : PillTone.neutral),
            if (isCurrentUserAdmin) ...[
              const SizedBox(width: 8),
              const StatusPill(label: "You're the Admin", tone: PillTone.info),
            ],
          ],
        ),
        const SizedBox(height: 20),

        if (isCurrentUserAdmin) ...[
          _AdminToolsCard(
            group: group,
            pendingMembers: _pendingMembers,
            isLoadingPending: _isLoadingPending,
            isBusy: _isBusy,
            onApprove: _approveMember,
            onStartGroup: group.status == 'gathering' ? _startGroup : null,
            onRotateCode: _rotateInviteCode,
            onSendInvite: _sendInvite,
          ),
          const SizedBox(height: 20),
        ],

        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.xl), boxShadow: cardShadow()),
          child: Column(
            children: [
              _row('Contribution Amount', '₦${formatAmount(group.contributionAmount)}'),
              _divider(),
              _row('Frequency', group.cycleFrequency?.label ?? '—'),
              _divider(),
              _row('Members', '${_members.length}${group.memberCap != null ? ' / ${group.memberCap}' : ''}'),
              _divider(),
              _row('Current Round', '${group.currentCycleNumber}'),
              _divider(),
              _row('Admin', admin.isNotEmpty ? admin.first.fullName : '—'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.xl), boxShadow: cardShadow()),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Invite Code', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(group.inviteCode ?? '—', style: GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary, letterSpacing: 2)),
                  ),
                  IconButton(onPressed: _copyInviteCode, icon: const Icon(Icons.copy_rounded, color: AppColors.textSecondary)),
                  IconButton(onPressed: _shareInviteLink, icon: const Icon(Icons.ios_share_rounded, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.xl), boxShadow: cardShadow()),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Rules', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              _ruleLine(group.shortfallPolicy?.description ?? 'Shortfall policy not set.'),
              if (group.memberCap != null) _ruleLine('Group is capped at ${group.memberCap} members.'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () => context.pushNamed(AppRoute.contribution.name, extra: widget.groupId),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandGreen,
              foregroundColor: AppColors.darkGreen,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
            ),
            child: Text('Contribute', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: _showMembers,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
            ),
            child: Text('View Members', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: () => context.pushNamed(AppRoute.groupChat.name, extra: widget.groupId),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
            ),
            child: Text('Open Group Chat', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: TextButton(
            onPressed: () => _leaveGroup(isCurrentUserAdmin),
            style: TextButton.styleFrom(backgroundColor: AppColors.dangerPale, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))),
            child: Text('Leave Group', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, color: AppColors.danger)),
          ),
        ),
      ],
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          Text(value, style: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _divider() => Divider(height: 1, color: Colors.grey[100]);

  Widget _ruleLine(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(padding: EdgeInsets.only(top: 5), child: Icon(Icons.circle, size: 5, color: AppColors.accentGreen)),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4))),
        ],
      ),
    );
  }
}

class _AdminToolsCard extends StatelessWidget {
  final GroupResponse group;
  final List<PendingMembership> pendingMembers;
  final bool isLoadingPending;
  final bool isBusy;
  final ValueChanged<PendingMembership> onApprove;
  final VoidCallback? onStartGroup;
  final VoidCallback onRotateCode;
  final VoidCallback onSendInvite;

  const _AdminToolsCard({
    required this.group,
    required this.pendingMembers,
    required this.isLoadingPending,
    required this.isBusy,
    required this.onApprove,
    required this.onStartGroup,
    required this.onRotateCode,
    required this.onSendInvite,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: cardShadow(),
        border: Border.all(color: AppColors.paleGreen, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.admin_panel_settings_rounded, color: AppColors.accentGreen, size: 18),
              const SizedBox(width: 8),
              Text('Admin Tools', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 14),

          // Pending requests
          if (isLoadingPending)
            const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: SkeletonBox(height: 40))
          else if (pendingMembers.isNotEmpty) ...[
            Text('Pending Requests (${pendingMembers.length})', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            for (final pending in pendingMembers)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(color: AppColors.paleGreen, shape: BoxShape.circle),
                      child: const Icon(Icons.person_outline_rounded, size: 16, color: AppColors.accentGreen),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Member request',
                            style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          Text(
                            'Requested ${formatShortDate(pending.createdAt)}',
                            style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: isBusy ? null : () => onApprove(pending),
                      style: TextButton.styleFrom(backgroundColor: AppColors.paleGreen, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
                      child: Text('Approve', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.accentGreen)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            Divider(color: Colors.grey[100]),
            const SizedBox(height: 10),
          ],

          // Actions
          Row(
            children: [
              if (onStartGroup != null)
                Expanded(
                  child: OutlinedButton(
                    onPressed: isBusy ? null : onStartGroup,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.accentGreen),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: Text('Start Group', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.accentGreen)),
                  ),
                ),
              if (onStartGroup != null) const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: isBusy ? null : onRotateCode,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: Text('New Invite Code', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: isBusy ? null : onSendInvite,
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 16, color: AppColors.accentGreen),
              label: Text('Invite Someone Directly', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.accentGreen)),
            ),
          ),
        ],
      ),
    );
  }
}
