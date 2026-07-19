import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/group_models.dart';
import '../../data/group_repository.dart';

/// Admin-only: choose how the payout rotation order is set before starting
/// the group — either randomized by the backend, or dragged into a manual
/// order. Pops with the updated [GroupResponse] on success, or null if
/// dismissed.
class StartGroupSheet extends ConsumerStatefulWidget {
  final String groupId;
  final List<GroupMember> members;

  const StartGroupSheet({super.key, required this.groupId, required this.members});

  static Future<GroupResponse?> show(BuildContext context, String groupId, List<GroupMember> members) {
    return showModalBottomSheet<GroupResponse>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => StartGroupSheet(groupId: groupId, members: members),
    );
  }

  @override
  ConsumerState<StartGroupSheet> createState() => _StartGroupSheetState();
}

enum _StartMode { randomize, manual }

class _StartGroupSheetState extends ConsumerState<StartGroupSheet> {
  _StartMode _mode = _StartMode.randomize;
  final List<GroupMember> _order = [];
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _order.addAll(widget.members);
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final updated = await ref.read(groupRepositoryProvider).startGroup(
            widget.groupId,
            randomize: _mode == _StartMode.randomize,
            manualOrder: _mode == _StartMode.manual ? _order.map((m) => m.userId).toList() : null,
          );
      if (!mounted) return;
      Navigator.pop(context, updated);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Start Group', style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'This locks in the payout rotation order and begins the first contribution cycle. This cannot be undone.',
            style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _modeChip(_StartMode.randomize, Icons.shuffle_rounded, 'Randomize Order')),
              const SizedBox(width: 10),
              Expanded(child: _modeChip(_StartMode.manual, Icons.format_list_numbered_rounded, 'Manual Order')),
            ],
          ),
          if (_mode == _StartMode.manual) ...[
            const SizedBox(height: 16),
            Text(
              'Drag to set the payout order — first member gets paid first.',
              style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ReorderableListView.builder(
                shrinkWrap: true,
                buildDefaultDragHandles: false,
                itemCount: _order.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final member = _order.removeAt(oldIndex);
                    _order.insert(newIndex, member);
                  });
                },
                // Without this, the dragged item falls back to Flutter's
                // default proxy Material, which renders as a plain black
                // box on some themes instead of matching the card style.
                proxyDecorator: (child, index, animation) {
                  return Material(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    elevation: 4,
                    shadowColor: Colors.black26,
                    child: child,
                  );
                },
                itemBuilder: (context, index) {
                  final member = _order[index];
                  return Container(
                    key: ValueKey(member.userId),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.border, width: 1),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(color: AppColors.paleGreen, shape: BoxShape.circle),
                          child: Text('${index + 1}', style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.accentGreen)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            member.fullName.isNotEmpty ? member.fullName : '@${member.username}',
                            style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        ReorderableDragStartListener(
                          index: index,
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.drag_handle_rounded, color: AppColors.textMuted, size: 20),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: (_isSubmitting || (_mode == _StartMode.manual && _order.isEmpty)) ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandGreen,
                foregroundColor: AppColors.darkGreen,
                disabledBackgroundColor: AppColors.brandGreen,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              ),
              child: _isSubmitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.darkGreen))
                  : Text('Start Group', style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeChip(_StartMode mode, IconData icon, String label) {
    final isSelected = _mode == mode;
    return GestureDetector(
      onTap: () => setState(() => _mode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.paleGreen : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: isSelected ? AppColors.accentGreen : AppColors.border, width: isSelected ? 2 : 1.2),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: AppColors.accentGreen),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center, style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}
