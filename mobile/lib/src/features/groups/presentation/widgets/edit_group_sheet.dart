import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/approval_switch_row.dart';
import '../../data/group_models.dart';
import '../../data/group_repository.dart';

const _kFieldTextStyle = TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary);

const _kFieldDecoration = InputDecoration(
  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(8)),
    borderSide: BorderSide(color: AppColors.border, width: 1.2),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(8)),
    borderSide: BorderSide(color: AppColors.border, width: 1.2),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(8)),
    borderSide: BorderSide(color: AppColors.darkGreen, width: 1.5),
  ),
);

/// Admin-only sheet to edit a subset of group settings via `PATCH /groups/{id}`.
/// Pops with the updated [GroupResponse] on success, or null if dismissed.
class EditGroupSheet extends ConsumerStatefulWidget {
  final GroupResponse group;

  const EditGroupSheet({super.key, required this.group});

  static Future<GroupResponse?> show(BuildContext context, GroupResponse group) {
    return showModalBottomSheet<GroupResponse>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => EditGroupSheet(group: group),
    );
  }

  @override
  ConsumerState<EditGroupSheet> createState() => _EditGroupSheetState();
}

class _EditGroupSheetState extends ConsumerState<EditGroupSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _memberCapController;
  TimeOfDay? _payoutTime;
  bool _isSubmitting = false;
  late bool _requiresApprovalForSwap;
  late bool _requiresApprovalForDelegate;

  /// Once a group is active, the backend locks anything that would break
  /// the math or scheduling for members already mid-rotation — contribution
  /// amount, cycle frequency, payout day/month, and payout time. Name and
  /// member cap stay editable throughout.
  bool get _isFinancialsLocked => widget.group.status == 'active';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.group.name);
    _amountController = TextEditingController(text: widget.group.contributionAmount.toStringAsFixed(0));
    _memberCapController = TextEditingController(text: widget.group.memberCap?.toString() ?? '');
    _requiresApprovalForSwap = widget.group.requiresApprovalForSwap;
    _requiresApprovalForDelegate = widget.group.requiresApprovalForDelegate;
  }

  Future<void> _pickPayoutTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _payoutTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) setState(() => _payoutTime = picked);
  }

  /// The backend's `payout_time` field expects "HH:MM:SSZ".
  String? _formatPayoutTime(TimeOfDay? time) {
    if (time == null) return null;
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return '$hh:$mm:00Z';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _memberCapController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = _isFinancialsLocked ? null : double.tryParse(_amountController.text.trim().replaceAll(',', ''));
    if (_nameController.text.trim().isEmpty || (!_isFinancialsLocked && (amount == null || amount <= 0))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid group name and amount', style: TextStyle(color: Colors.white)), backgroundColor: AppColors.darkGreen),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final memberCapText = _memberCapController.text.trim();
      final updated = await ref.read(groupRepositoryProvider).updateGroup(
            widget.group.id,
            GroupUpdateRequest(
              name: _nameController.text.trim(),
              // Once active, the backend rejects any change to these — so
              // they're just never sent rather than surfacing a confusing
              // "silent" failure.
              contributionAmount: _isFinancialsLocked ? null : amount,
              // shortfallPolicy intentionally omitted — no UI for it, and
              // leaving it null here means the existing value is preserved.
              memberCap: memberCapText.isEmpty ? null : int.tryParse(memberCapText),
              payoutTime: _isFinancialsLocked ? null : _formatPayoutTime(_payoutTime),
              requiresApprovalForSwap: _requiresApprovalForSwap,
              requiresApprovalForDelegate: _requiresApprovalForDelegate,
            ),
          );
      if (!mounted) return;
      Navigator.pop(context, updated);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message, style: TextStyle(color: Colors.white)), backgroundColor: AppColors.darkGreen));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Edit Group', style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 12),
            if (_isFinancialsLocked) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.paleGreen, borderRadius: BorderRadius.circular(AppRadius.md)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lock_outline_rounded, color: AppColors.accentGreen, size: 16),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "This group is active, so the contribution amount and payout time are locked to keep payouts fair for everyone already in the rotation. Finish this round, then start a new group to change them.",
                        style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            _label('Group Name'),
            const SizedBox(height: 8),
            TextField(controller: _nameController, style: _kFieldTextStyle, decoration: _kFieldDecoration),
            const SizedBox(height: 20),
            _label('Contribution Amount'),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              enabled: !_isFinancialsLocked,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: _kFieldTextStyle.copyWith(color: _isFinancialsLocked ? AppColors.textMuted : AppColors.textPrimary),
              decoration: _kFieldDecoration.copyWith(
                prefixText: '₦ ',
                suffixIcon: _isFinancialsLocked ? const Icon(Icons.lock_outline_rounded, color: AppColors.textMuted, size: 18) : null,
                fillColor: _isFinancialsLocked ? AppColors.background : null,
                filled: _isFinancialsLocked,
              ),
            ),
            const SizedBox(height: 20),
            _label('Payout Time (optional)'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _isFinancialsLocked ? null : _pickPayoutTime,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: _isFinancialsLocked ? AppColors.background : null,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border, width: 1.2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _payoutTime != null ? _payoutTime!.format(context) : 'Not set',
                      style: TextStyle(fontFamily: 'PlusJakartaSans',
                        fontSize: 14,
                        color: _isFinancialsLocked ? AppColors.textMuted : (_payoutTime != null ? AppColors.textPrimary : AppColors.hint),
                        fontWeight: _payoutTime != null ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    Icon(_isFinancialsLocked ? Icons.lock_outline_rounded : Icons.access_time_rounded, color: AppColors.textMuted, size: _isFinancialsLocked ? 18 : 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _label('Maximum Members (optional)'),
            const SizedBox(height: 8),
            TextField(controller: _memberCapController, keyboardType: TextInputType.number, style: _kFieldTextStyle, decoration: _kFieldDecoration),
            const SizedBox(height: 20),
            _label('Cycle Requests'),
            const SizedBox(height: 8),
            ApprovalSwitchRow(
              title: 'Require approval for swaps',
              subtitle: "You'll need to approve members swapping their payout order.",
              value: _requiresApprovalForSwap,
              onChanged: (v) => setState(() => _requiresApprovalForSwap = v),
            ),
            const SizedBox(height: 10),
            ApprovalSwitchRow(
              title: 'Require approval for delegations',
              subtitle: "You'll need to approve a member delegating their payout to someone else.",
              value: _requiresApprovalForDelegate,
              onChanged: (v) => setState(() => _requiresApprovalForDelegate = v),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandGreen,
                  foregroundColor: AppColors.darkGreen,
                  disabledBackgroundColor: AppColors.brandGreen,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                ),
                child: _isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.darkGreen))
                    : Text('Save Changes', style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(text, style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary));
  }
}
