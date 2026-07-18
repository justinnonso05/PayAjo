import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/group_models.dart';
import '../../data/group_repository.dart';

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

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.group.name);
    _amountController = TextEditingController(text: widget.group.contributionAmount.toStringAsFixed(0));
    _memberCapController = TextEditingController(text: widget.group.memberCap?.toString() ?? '');
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
    final amount = double.tryParse(_amountController.text.trim().replaceAll(',', ''));
    if (_nameController.text.trim().isEmpty || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid group name and amount'), backgroundColor: AppColors.darkGreen),
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
              contributionAmount: amount,
              // shortfallPolicy intentionally omitted — no UI for it, and
              // leaving it null here means the existing value is preserved.
              memberCap: memberCapText.isEmpty ? null : int.tryParse(memberCapText),
              payoutTime: _formatPayoutTime(_payoutTime),
            ),
          );
      if (!mounted) return;
      Navigator.pop(context, updated);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.darkGreen));
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
                Text('Edit Group', style: GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 12),
            _label('Group Name'),
            const SizedBox(height: 8),
            TextField(controller: _nameController, decoration: _kFieldDecoration),
            const SizedBox(height: 20),
            _label('Contribution Amount'),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: _kFieldDecoration.copyWith(prefixText: '₦ '),
            ),
            const SizedBox(height: 20),
            _label('Payout Time (optional)'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickPayoutTime,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border, width: 1.2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _payoutTime != null ? _payoutTime!.format(context) : 'Not set',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: _payoutTime != null ? AppColors.textPrimary : AppColors.hint,
                        fontWeight: _payoutTime != null ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    const Icon(Icons.access_time_rounded, color: AppColors.hint, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _label('Maximum Members (optional)'),
            const SizedBox(height: 8),
            TextField(controller: _memberCapController, keyboardType: TextInputType.number, decoration: _kFieldDecoration),
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
                    : Text('Save Changes', style: GoogleFonts.spaceGrotesk(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(text, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary));
  }
}
