import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/pin_entry_sheet.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../../core/widgets/status_pill.dart';
import '../../../core/widgets/success_bottom_sheet.dart';
import '../../../routing/app_router.dart';
import '../../auth/data/user_repository.dart';
import '../../wallet/data/wallet_controller.dart';
import '../data/contribution_status.dart';
import '../data/group_models.dart';
import '../data/group_repository.dart';
import 'widgets/edit_group_sheet.dart';
import 'widgets/send_invite_sheet.dart';
import 'widgets/start_group_sheet.dart';

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
  List<GroupRotationEntry> _rotations = [];
  bool _isLoading = true;
  bool _isLoadingPending = false;
  bool _isLoadingRotations = true;
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
      _loadRotations();
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadRotations() async {
    setState(() => _isLoadingRotations = true);
    try {
      final rotations = await ref.read(groupRepositoryProvider).getRotations(widget.groupId);
      if (!mounted) return;
      setState(() {
        _rotations = rotations;
        _isLoadingRotations = false;
      });
    } catch (_) {
      // The rotation schedule is only meaningful once a group has started —
      // an error here (e.g. group still gathering) just means "nothing to show".
      if (mounted) setState(() => _isLoadingRotations = false);
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Member approved', style: TextStyle(color: Colors.white)), backgroundColor: AppColors.darkGreen));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message, style: TextStyle(color: Colors.white)), backgroundColor: AppColors.darkGreen));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _refreshMembers() async {
    final members = await ref.read(groupRepositoryProvider).getMembers(widget.groupId);
    if (mounted) setState(() => _members = members);
  }

  Future<void> _startGroup() async {
    final updated = await StartGroupSheet.show(context, widget.groupId, _members);
    if (updated == null || !mounted) return;
    setState(() => _group = updated);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Group started!', style: TextStyle(color: Colors.white)), backgroundColor: AppColors.darkGreen));
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('New invite code generated', style: TextStyle(color: Colors.white)), backgroundColor: AppColors.darkGreen));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message, style: TextStyle(color: Colors.white)), backgroundColor: AppColors.darkGreen));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _sendInvite() async {
    final sent = await SendInviteSheet.show(context, widget.groupId);
    if (sent != true || !mounted) return;
    SuccessBottomSheet.show(
      context,
      title: 'Invite Sent',
      subtitle: "They'll see it under their invites and can join the group once they accept.",
      primaryLabel: 'Done',
      onPrimary: () => Navigator.pop(context),
    );
  }

  Future<void> _sendReminders() async {
    setState(() => _isBusy = true);
    try {
      await ref.read(groupRepositoryProvider).sendRemindersBulk(widget.groupId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reminders sent to everyone who still owes this round', style: TextStyle(color: Colors.white)), backgroundColor: AppColors.darkGreen),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message, style: TextStyle(color: Colors.white)), backgroundColor: AppColors.darkGreen));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send reminders: $e', style: TextStyle(color: Colors.white)), backgroundColor: AppColors.darkGreen),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  /// Manually runs the payout scheduler across every group (not just this
  /// one) — a testing/demo shortcut so a due payout doesn't have to wait
  /// for the real cron interval. Refreshes this group afterward in case it
  /// was the one that paid out.
  Future<void> _triggerScheduler() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Run payout check?'),
        content: const Text(
          "This manually runs the payout scheduler across ALL groups, not just this one — it's a testing/demo shortcut, not something you'd normally need to press.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Run Check')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isBusy = true);
    try {
      final message = await ref.read(groupRepositoryProvider).triggerScheduler();
      final updated = await ref.read(groupRepositoryProvider).getGroup(widget.groupId);
      if (!mounted) return;
      setState(() => _group = updated);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message, style: TextStyle(color: Colors.white)), backgroundColor: AppColors.darkGreen));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message, style: TextStyle(color: Colors.white)), backgroundColor: AppColors.darkGreen));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not run payout check: $e', style: TextStyle(color: Colors.white)), backgroundColor: AppColors.darkGreen),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _remindMember(GroupMember member) async {
    try {
      await ref.read(groupRepositoryProvider).sendMemberReminder(widget.groupId, member.userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reminder sent to ${member.fullName}', style: TextStyle(color: Colors.white)), backgroundColor: AppColors.darkGreen),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message, style: TextStyle(color: Colors.white)), backgroundColor: AppColors.darkGreen));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send reminder: $e', style: TextStyle(color: Colors.white)), backgroundColor: AppColors.darkGreen),
      );
    }
  }

  /// Toggles auto-debit for the current user's own membership. PIN-confirmed
  /// since it authorizes the backend to pull contributions automatically.
  Future<void> _setAutoDebit({required bool enabled, required int daysBefore}) async {
    final pin = await PinEntrySheet.show(
      context,
      title: enabled ? 'Enable Auto-Debit' : 'Turn Off Auto-Debit',
      subtitle: enabled
          ? "Confirm with your PIN. We'll pay this group's contribution from your wallet automatically, $daysBefore day${daysBefore == 1 ? '' : 's'} before payout, as long as you haven't already paid."
          : "Confirm with your PIN to stop automatic contributions for this group.",
    );
    if (pin == null || !mounted) return;

    setState(() => _isBusy = true);
    try {
      final updated = await ref.read(groupRepositoryProvider).setupAutoDebit(
            widget.groupId,
            enabled: enabled,
            daysBefore: daysBefore,
            pin: pin,
          );
      if (!mounted) return;
      setState(() {
        _members = [
          for (final m in _members) m.userId == updated.userId ? updated : m,
        ];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(enabled ? 'Auto-debit enabled' : 'Auto-debit turned off', style: TextStyle(color: Colors.white)), backgroundColor: AppColors.darkGreen),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message, style: TextStyle(color: Colors.white)), backgroundColor: AppColors.darkGreen));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _editGroup() async {
    final updated = await EditGroupSheet.show(context, _group!);
    if (updated == null) return;
    setState(() => _group = updated);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Group updated', style: TextStyle(color: Colors.white)), backgroundColor: AppColors.darkGreen));
  }

  void _copyInviteCode() {
    final code = _group?.inviteCode;
    if (code == null) return;
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invite code copied', style: TextStyle(color: Colors.white)), backgroundColor: AppColors.darkGreen));
  }

  void _shareInviteLink() {
    final code = _group?.inviteCode;
    if (code == null) return;
    Clipboard.setData(ClipboardData(text: 'Join my AjoPay group with code $code'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invite message copied. Paste it anywhere to share.', style: TextStyle(color: Colors.white)), backgroundColor: AppColors.darkGreen),
    );
  }

  /// For an active group, members who still owe this round sort first —
  /// that's the list an admin actually wants when deciding who to remind.
  List<GroupMember> _sortedForMembersList() {
    if (_group?.status != 'active') return _members;
    final owes = _members.where((m) => !m.hasPaidCurrentCycle).toList();
    final paid = _members.where((m) => m.hasPaidCurrentCycle).toList();
    return [...owes, ...paid];
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
              Text('Members (${_members.length})', style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              Expanded(
                child: Builder(
                  builder: (context) {
                    // Members who still owe surface first — the admin's
                    // reason for opening this list is usually "who do I chase".
                    final sorted = _sortedForMembersList();
                    return ListView.separated(
                      controller: scrollController,
                      itemCount: sorted.length,
                      separatorBuilder: (context, index) => Divider(color: Colors.grey[100]),
                      itemBuilder: (context, index) => _MemberRow(
                        member: sorted[index],
                        isGroupActive: _group?.status == 'active',
                        canRemind: _isCurrentUserAdmin && !sorted[index].isAdmin && _group?.status == 'active',
                        onRemind: () => _remindMember(sorted[index]),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: Text('Group Details', style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Padding(padding: EdgeInsets.all(24), child: SkeletonCard(height: 400))
            : _error != null
                ? Center(child: Text(_error!, style: TextStyle(fontFamily: 'PlusJakartaSans', color: AppColors.textSecondary)))
                : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final group = _group!;
    final admin = _members.where((m) => m.isAdmin).toList();
    final isCurrentUserAdmin = _isCurrentUserAdmin;
    final currentUserId = ref.read(currentUserProvider)?.id;
    final currentMemberMatches = _members.where((m) => m.userId == currentUserId);
    final currentMember = currentMemberMatches.isEmpty ? null : currentMemberMatches.first;
    // Prefer the backend's ground-truth `has_paid_current_cycle` for the
    // current user; fall back to the wallet-history heuristic only if their
    // membership record hasn't loaded yet.
    final hasPaid = currentMember?.hasPaidCurrentCycle ?? hasPaidCurrentRound(group, ref.watch(walletTransactionsControllerProvider).items);

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(group.name, style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            ),
            if (isCurrentUserAdmin)
              IconButton(onPressed: _isBusy ? null : _editGroup, icon: const Icon(Icons.edit_outlined, color: AppColors.textSecondary)),
          ],
        ),
        Row(
          children: [
            StatusPill(label: group.status, tone: group.status == 'active' ? PillTone.success : PillTone.neutral),
            if (group.status == 'active' && hasPaid) ...[
              const SizedBox(width: 8),
              const StatusPill(label: 'Paid this round', tone: PillTone.success),
            ],
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
            onSendReminders: group.status == 'active' ? _sendReminders : null,
            onTriggerScheduler: _triggerScheduler,
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
              _row('Pool Balance (this round)', '₦${formatAmount(group.poolBalance)}'),
              _divider(),
              _row('Next Payout', group.nextPayoutDate != null ? formatShortDate(group.nextPayoutDate!) : 'TBD'),
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
              Text('Invite Code', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(group.inviteCode ?? '—', style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary, letterSpacing: 2)),
                  ),
                  IconButton(onPressed: _copyInviteCode, icon: const Icon(Icons.copy_rounded, color: AppColors.textSecondary)),
                  IconButton(onPressed: _shareInviteLink, icon: const Icon(Icons.ios_share_rounded, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
        ),
        if (group.memberCap != null) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.xl), boxShadow: cardShadow()),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rules', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                _ruleLine('Group is capped at ${group.memberCap} members.'),
              ],
            ),
          ),
        ],
        if (group.status == 'active') ...[
          const SizedBox(height: 20),
          _PayoutScheduleCard(rotations: _rotations, isLoading: _isLoadingRotations),
        ],
        if (group.status == 'active' && currentMember != null) ...[
          const SizedBox(height: 20),
          _AutoDebitCard(
            member: currentMember,
            isBusy: _isBusy,
            onChanged: (enabled, daysBefore) => _setAutoDebit(enabled: enabled, daysBefore: daysBefore),
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: group.status == 'active' && !hasPaid
                ? () => context.pushNamed(AppRoute.contribution.name, extra: widget.groupId)
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandGreen,
              foregroundColor: AppColors.darkGreen,
              disabledBackgroundColor: AppColors.brandGreen.withValues(alpha: 0.4),
              disabledForegroundColor: AppColors.darkGreen.withValues(alpha: 0.6),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
            ),
            child: Text(
              group.status != 'active'
                  ? 'Contribute (group not started)'
                  : hasPaid
                      ? 'Already Contributed'
                      : 'Contribute',
              style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.bold, fontSize: group.status == 'active' && !hasPaid ? 15 : 13),
            ),
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
            child: Text('View Members', style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
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
            child: Text('Open Group Chat', style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
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
          Text(label, style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          Text(value, style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
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
          Expanded(child: Text(text, style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12.5, color: AppColors.textSecondary, height: 1.4))),
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
  final VoidCallback? onSendReminders;
  final VoidCallback onTriggerScheduler;

  const _AdminToolsCard({
    required this.group,
    required this.pendingMembers,
    required this.isLoadingPending,
    required this.isBusy,
    required this.onApprove,
    required this.onStartGroup,
    required this.onRotateCode,
    required this.onSendInvite,
    required this.onSendReminders,
    required this.onTriggerScheduler,
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
              Text('Admin Tools', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 14),

          // Pending requests
          if (isLoadingPending)
            const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: SkeletonBox(height: 40))
          else if (pendingMembers.isNotEmpty) ...[
            Text('Pending Requests (${pendingMembers.length})', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.bold)),
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
                            pending.fullName.isNotEmpty ? pending.fullName : '@${pending.username}',
                            style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          Text(
                            'Requested ${formatShortDate(pending.joinedAt)}',
                            style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: isBusy ? null : () => onApprove(pending),
                      style: TextButton.styleFrom(backgroundColor: AppColors.paleGreen, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
                      child: Text('Approve', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.accentGreen)),
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
                    child: Text('Start Group', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.accentGreen)),
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
                  child: Text('New Invite Code', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
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
              label: Text('Invite Someone Directly', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.accentGreen)),
            ),
          ),
          if (onSendReminders != null)
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: isBusy ? null : onSendReminders,
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
                icon: const Icon(Icons.notifications_active_outlined, size: 16, color: AppColors.warning),
                label: Text('Remind Everyone Who Owes', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.warning)),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: isBusy ? null : onTriggerScheduler,
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
              icon: const Icon(Icons.bolt_rounded, size: 16, color: AppColors.info),
              label: Text('Run Payout Check (Demo)', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.info)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PayoutScheduleCard extends StatelessWidget {
  final List<GroupRotationEntry> rotations;
  final bool isLoading;

  const _PayoutScheduleCard({required this.rotations, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.xl), boxShadow: cardShadow()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Payout Schedule', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (isLoading)
            const SkeletonBox(height: 60)
          else if (rotations.isEmpty)
            Text('No rotation order yet.', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12.5, color: AppColors.textMuted))
          else
            for (var i = 0; i < rotations.length; i++) ...[
              _rotationRow(rotations[i]),
              if (i != rotations.length - 1) Divider(height: 1, color: Colors.grey[100]),
            ],
        ],
      ),
    );
  }

  Widget _rotationRow(GroupRotationEntry entry) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: entry.isCurrent ? AppColors.brandGreen : (entry.isCompleted ? AppColors.paleGreen : AppColors.divider),
              shape: BoxShape.circle,
            ),
            child: Text(
              '${entry.cycleNumber}',
              style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.darkGreen),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.fullName.isNotEmpty ? entry.fullName : '@${entry.username}',
                  style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                if (entry.payoutDate != null)
                  Text(formatShortDate(entry.payoutDate!), style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
          if (entry.isCurrent)
            const StatusPill(label: 'Next', tone: PillTone.success)
          else if (entry.isCompleted)
            const StatusPill(label: 'Paid Out', tone: PillTone.info)
          else
            const StatusPill(label: 'Upcoming', tone: PillTone.neutral),
        ],
      ),
    );
  }
}

class _AutoDebitCard extends StatefulWidget {
  final GroupMember member;
  final bool isBusy;
  final void Function(bool enabled, int daysBefore) onChanged;

  const _AutoDebitCard({required this.member, required this.isBusy, required this.onChanged});

  @override
  State<_AutoDebitCard> createState() => _AutoDebitCardState();
}

class _AutoDebitCardState extends State<_AutoDebitCard> {
  late int _daysBefore = widget.member.autoDebitDaysBefore;

  @override
  void didUpdateWidget(covariant _AutoDebitCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.member.autoDebitDaysBefore != widget.member.autoDebitDaysBefore) {
      _daysBefore = widget.member.autoDebitDaysBefore;
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.member.autoDebitEnabled;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.xl), boxShadow: cardShadow()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Auto-Debit', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.bold)),
              ),
              Switch(
                value: enabled,
                onChanged: widget.isBusy ? null : (value) => widget.onChanged(value, _daysBefore),
                activeThumbColor: AppColors.darkGreen,
                activeTrackColor: AppColors.brandGreen,
              ),
            ],
          ),
          Text(
            "Automatically pay this group's contribution from your wallet before each payout.",
            style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12.5, color: AppColors.textSecondary, height: 1.4),
          ),
          if (enabled) ...[
            const SizedBox(height: 14),
            Text('Debit this many days before payout', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11.5, color: AppColors.textMuted, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final days in [1, 2, 3]) ...[
                  ChoiceChip(
                    label: Text('$days day${days == 1 ? '' : 's'}'),
                    selected: _daysBefore == days,
                    onSelected: widget.isBusy
                        ? null
                        : (selected) {
                            if (!selected) return;
                            setState(() => _daysBefore = days);
                            widget.onChanged(true, days);
                          },
                    selectedColor: AppColors.brandGreen,
                    labelStyle: TextStyle(fontFamily: 'PlusJakartaSans', 
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _daysBefore == days ? AppColors.darkGreen : AppColors.textSecondary,
                    ),
                    backgroundColor: AppColors.background,
                    side: BorderSide(color: _daysBefore == days ? AppColors.brandGreen : AppColors.border),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  final GroupMember member;
  final bool isGroupActive;
  final bool canRemind;
  final VoidCallback onRemind;

  const _MemberRow({
    required this.member,
    required this.isGroupActive,
    required this.canRemind,
    required this.onRemind,
  });

  @override
  Widget build(BuildContext context) {
    // "Active" is the default, expected state — only worth a pill when the
    // role or status says something the admin wouldn't already assume.
    final roleLabel = member.isAdmin ? 'Admin' : (member.status == 'active' ? null : member.status);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(color: AppColors.paleGreen, shape: BoxShape.circle),
                child: Center(
                  child: Text(
                    member.firstName.isNotEmpty ? member.firstName[0].toUpperCase() : '?',
                    style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.bold, color: AppColors.accentGreen),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(member.fullName, style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    Text('@${member.username}', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
              ),
              if (roleLabel != null)
                StatusPill(
                  label: roleLabel,
                  tone: member.isAdmin ? PillTone.info : PillTone.warning,
                ),
            ],
          ),
          if (isGroupActive) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 50),
              child: Row(
                children: [
                  StatusPill(
                    label: member.hasPaidCurrentCycle ? 'Paid' : 'Owes',
                    tone: member.hasPaidCurrentCycle ? PillTone.success : PillTone.danger,
                  ),
                  const Spacer(),
                  if (canRemind)
                    TextButton.icon(
                      onPressed: onRemind,
                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      icon: const Icon(Icons.notifications_active_outlined, size: 15, color: AppColors.warning),
                      label: Text('Remind', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.warning)),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
