import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/data/user_repository.dart';
import '../../data/group_repository.dart';

/// Admin-only: look up a user by exact email/username, preview who they
/// are (name + risk score) before sending, then send the invite —
/// separate from sharing the group's invite code.
class SendInviteSheet extends ConsumerStatefulWidget {
  final String groupId;

  const SendInviteSheet({super.key, required this.groupId});

  static Future<bool?> show(BuildContext context, String groupId) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => SendInviteSheet(groupId: groupId),
    );
  }

  @override
  ConsumerState<SendInviteSheet> createState() => _SendInviteSheetState();
}

enum _SearchStatus { idle, searching, found, notFound }

class _SendInviteSheetState extends ConsumerState<SendInviteSheet> {
  final _controller = TextEditingController();
  Timer? _debounce;
  int _requestId = 0;
  _SearchStatus _status = _SearchStatus.idle;
  UserSearchResult? _result;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _status = _SearchStatus.idle;
        _result = null;
      });
      return;
    }
    setState(() => _status = _SearchStatus.searching);
    _debounce = Timer(const Duration(milliseconds: 450), () => _search(query));
  }

  Future<void> _search(String query) async {
    final thisRequest = ++_requestId;
    final result = await ref.read(userRepositoryProvider).searchUser(query);
    if (!mounted || thisRequest != _requestId) return;
    setState(() {
      _result = result;
      _status = result != null ? _SearchStatus.found : _SearchStatus.notFound;
    });
  }

  Future<void> _submit() async {
    final result = _result;
    if (result == null) return;

    setState(() => _isSubmitting = true);
    try {
      await ref.read(groupRepositoryProvider).sendInvite(widget.groupId, result.username);
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message, style: TextStyle(color: Colors.white)), backgroundColor: AppColors.darkGreen));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong sending the invite. Please try again.', style: TextStyle(color: Colors.white)), backgroundColor: AppColors.darkGreen),
      );
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
              Text('Invite Someone', style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "They'll see this invite next time they open PayAjo.",
            style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          Text('Email or Username', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            autofocus: true,
            onChanged: _onChanged,
            style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'e.g. amara or amara@email.com',
              hintStyle: const TextStyle(color: AppColors.hint, fontSize: 14),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              suffixIcon: _status == _SearchStatus.searching
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentGreen)),
                    )
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border, width: 1.2)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border, width: 1.2)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.darkGreen, width: 1.5)),
            ),
          ),
          const SizedBox(height: 16),
          if (_status == _SearchStatus.notFound)
            Text(
              'No PayAjo user found with that email or username.',
              style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12.5, color: AppColors.danger, fontWeight: FontWeight.w600),
            ),
          if (_status == _SearchStatus.found && _result != null) _UserPreviewCard(result: _result!),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: (_status == _SearchStatus.found && !_isSubmitting) ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandGreen,
                foregroundColor: AppColors.darkGreen,
                disabledBackgroundColor: AppColors.brandGreen.withValues(alpha: 0.4),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              ),
              child: _isSubmitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.darkGreen))
                  : Text('Send Invite', style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserPreviewCard extends StatelessWidget {
  final UserSearchResult result;

  const _UserPreviewCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final isHighRisk = result.riskScore >= 50;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.paleGreen, borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Row(
        children: [
          const CircleAvatar(radius: 18, backgroundColor: AppColors.brandGreen, child: Icon(Icons.person_rounded, color: AppColors.darkGreen, size: 18)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.fullName.isNotEmpty ? result.fullName : '@${result.username}',
                  style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.darkGreen),
                ),
                Text('@${result.username}', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, color: AppColors.darkGreen.withValues(alpha: 0.7))),
              ],
            ),
          ),
          if (isHighRisk)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: AppColors.dangerPale, borderRadius: BorderRadius.circular(20)),
              child: Text('High risk', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.danger)),
            ),
        ],
      ),
    );
  }
}
