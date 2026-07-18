import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../routing/app_router.dart';
import '../../../groups/data/group_repository.dart';
import '../../../home/data/home_controller.dart';
import '../join_group_success_screen.dart';

class JoinGroupSheet extends ConsumerStatefulWidget {
  const JoinGroupSheet({super.key});

  @override
  ConsumerState<JoinGroupSheet> createState() => _JoinGroupSheetState();
}

class _JoinGroupSheetState extends ConsumerState<JoinGroupSheet> {
  final _inviteCodeController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _inviteCodeController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: const Color(0xFF1D3108)),
    );
  }

  Future<void> _submit() async {
    final code = _inviteCodeController.text.trim();
    if (code.isEmpty) {
      _showError('Please enter an invite code.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final repository = ref.read(groupRepositoryProvider);
      final group = await repository.joinGroup(code);
      final memberCount = await repository.getMemberCount(group.id);

      if (!mounted) return;
      ref.read(homeControllerProvider.notifier).refresh();
      Navigator.pop(context);
      context.goNamed(
        AppRoute.joinGroupSuccess.name,
        extra: JoinGroupSuccessData(
          groupName: group.name,
          memberCount: memberCount,
          contributionAmount: '₦${formatAmount(group.contributionAmount)}',
          contributionFrequency: group.cycleFrequency?.label ?? '—',
        ),
      );
    } on ApiException catch (e) {
      _showError(e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Join a Group',
                style: GoogleFonts.spaceGrotesk(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF1D3108)),
              ),
              IconButton(
                onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Enter the invitation code sent to you by a group member.',
            style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),

          Text(
            'Invite Code',
            style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF1D3108)),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _inviteCodeController,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'e.g. AJO-8392-XYZ',
              hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1.2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1.2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF1D3108), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFACEC87),
                foregroundColor: const Color(0xFF1D3108),
                disabledBackgroundColor: const Color(0xFFACEC87),
                disabledForegroundColor: const Color(0xFF1D3108),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF1D3108)),
                    )
                  : Text('Join Group', style: GoogleFonts.spaceGrotesk(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
