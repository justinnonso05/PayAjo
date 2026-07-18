import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../home/data/home_controller.dart';
import '../data/group_invites_controller.dart';

class MyInvitesScreen extends ConsumerStatefulWidget {
  const MyInvitesScreen({super.key});

  @override
  ConsumerState<MyInvitesScreen> createState() => _MyInvitesScreenState();
}

class _MyInvitesScreenState extends ConsumerState<MyInvitesScreen> {
  String? _respondingInviteId;

  Future<void> _respond(GroupInviteWithGroup item, bool accept) async {
    setState(() => _respondingInviteId = item.invite.id);
    try {
      await ref.read(groupInvitesControllerProvider.notifier).respond(item.invite.id, accept: accept);
      if (accept) {
        // A newly-accepted invite means a new group membership — refresh Home's carousel.
        ref.read(homeControllerProvider.notifier).refresh();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accept ? 'Joined ${item.groupName}!' : 'Invite declined'),
          backgroundColor: AppColors.darkGreen,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.darkGreen));
    } finally {
      if (mounted) setState(() => _respondingInviteId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(groupInvitesControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: Text('My Invites', style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accentGreen,
          onRefresh: () => ref.read(groupInvitesControllerProvider.notifier).refresh(),
          child: _buildBody(state),
        ),
      ),
    );
  }

  Widget _buildBody(GroupInvitesState state) {
    if (state.isLoading && state.invites.isEmpty) {
      return ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        itemCount: 3,
        itemBuilder: (context, index) => const Padding(padding: EdgeInsets.only(bottom: 16), child: SkeletonCard(height: 96)),
      );
    }

    if (state.error != null && state.invites.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          EmptyState(icon: Icons.wifi_off_rounded, title: "Couldn't load invites", subtitle: state.error),
        ],
      );
    }

    if (state.invites.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          EmptyState(
            icon: Icons.mail_outline_rounded,
            title: 'No pending invites.',
            subtitle: "When a group admin invites you directly, it'll show up here.",
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      itemCount: state.invites.length,
      itemBuilder: (context, index) {
        final item = state.invites[index];
        final isBusy = _respondingInviteId == item.invite.id;
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.xl), boxShadow: cardShadow()),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(color: AppColors.paleGreen, shape: BoxShape.circle),
                      child: const Icon(Icons.groups_rounded, color: AppColors.accentGreen),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.groupName, style: GoogleFonts.spaceGrotesk(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          Text('Invited ${formatShortDate(item.invite.createdAt)}', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isBusy ? null : () => _respond(item, false),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        child: Text('Decline', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isBusy ? null : () => _respond(item, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brandGreen,
                          foregroundColor: AppColors.darkGreen,
                          disabledBackgroundColor: AppColors.brandGreen,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        child: isBusy
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.darkGreen))
                            : Text('Accept', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
