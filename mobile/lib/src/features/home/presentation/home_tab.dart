import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../../core/widgets/status_pill.dart';
import '../../../routing/app_router.dart';
import '../../auth/data/user_repository.dart';
import '../../groups/data/group_invites_controller.dart';
import '../../groups/data/group_models.dart';
import '../../auth/data/user_profile.dart';
import '../../shell/data/shell_tab_provider.dart';
import '../../wallet/data/wallet_controller.dart';
import '../../wallet/data/wallet_models.dart';
import '../data/home_controller.dart';

class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({super.key});

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab> {
  final _pageController = PageController(viewportFraction: 0.92);
  int _selectedGroupIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final homeState = ref.watch(homeControllerProvider);
    final profileState = ref.watch(userProfileControllerProvider);
    final pendingInvites = ref.watch(groupInvitesControllerProvider).invites;

    // Clamp in case the list shrank (e.g. after leaving a group) since last selection.
    final selectedIndex = homeState.summaries.isEmpty ? 0 : _selectedGroupIndex.clamp(0, homeState.summaries.length - 1);
    final isOnAddGroupCard = homeState.hasGroup && selectedIndex >= homeState.summaries.length;
    final selectedGroupId = homeState.hasGroup && !isOnAddGroupCard ? homeState.summaries[selectedIndex].group.id : null;
    final isSelectedGroupAdmin = homeState.hasGroup && !isOnAddGroupCard ? homeState.summaries[selectedIndex].membership.isAdmin : false;
    // +1 slot for the trailing "add another group" card.
    final carouselCount = homeState.summaries.length + 1;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppColors.accentGreen,
        onRefresh: () async {
          await Future.wait([
            ref.read(homeControllerProvider.notifier).refresh(),
            ref.read(userProfileControllerProvider.notifier).refresh(),
            ref.read(walletTransactionsControllerProvider.notifier).refresh(),
            ref.read(groupInvitesControllerProvider.notifier).refresh(),
          ]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 100),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _GreetingHeader(
                name: profileState.profile?.firstName,
                onAvatarTap: () => ref.read(selectedTabIndexProvider.notifier).state = 3,
              ),
            ),
            const SizedBox(height: 24),
            if (pendingInvites.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _PendingInvitesBanner(count: pendingInvites.length),
              ),
              const SizedBox(height: 16),
            ],
            if (homeState.isLoading && !homeState.hasGroup)
              const Padding(padding: EdgeInsets.symmetric(horizontal: 24), child: SkeletonCard(height: 220))
            else if (homeState.hasGroup) ...[
              SizedBox(
                height: 224,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: carouselCount,
                  onPageChanged: (index) => setState(() => _selectedGroupIndex = index),
                  itemBuilder: (context, index) {
                    if (index >= homeState.summaries.length) {
                      return const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: _AddGroupCard());
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: _ActiveGroupCard(summary: homeState.summaries[index]),
                    );
                  },
                ),
              ),
              if (carouselCount > 1) ...[
                const SizedBox(height: 12),
                _PageDots(count: carouselCount, index: selectedIndex),
              ],
            ] else
              Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: _NoGroupCard()),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (profileState.profile?.personalReservedAccountNumber != null) ...[
                    _ReservedAccountCard(profile: profileState.profile!),
                    const SizedBox(height: 24),
                  ],
                  const SectionHeader(title: 'Quick Actions'),
                  const SizedBox(height: 14),
                  _QuickActions(hasGroup: selectedGroupId != null, groupId: selectedGroupId, isAdmin: isSelectedGroupAdmin),
                  const SizedBox(height: 28),
                  if (selectedGroupId != null) ...[
                    const SectionHeader(title: 'Upcoming Contributions'),
                    const SizedBox(height: 12),
                    _UpcomingContributions(summary: homeState.summaries[selectedIndex]),
                    const SizedBox(height: 28),
                  ],
                  const SectionHeader(title: 'Recent Activity'),
                  const SizedBox(height: 12),
                  const _RecentActivity(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  final int count;
  final int index;

  const _PageDots({required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive ? AppColors.accentGreen : AppColors.divider,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

class _GreetingHeader extends StatelessWidget {
  final String? name;
  final VoidCallback onAvatarTap;

  const _GreetingHeader({this.name, required this.onAvatarTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${greeting()},',
              style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 2),
            Text(
              '${name?.isNotEmpty == true ? name : 'there'} 👋',
              style: GoogleFonts.spaceGrotesk(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ],
        ),
        GestureDetector(
          onTap: onAvatarTap,
          child: Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(color: AppColors.paleGreen, shape: BoxShape.circle),
            child: Center(
              child: Text(
                (name?.isNotEmpty == true ? name![0] : '?').toUpperCase(),
                style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.accentGreen),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActiveGroupCard extends StatelessWidget {
  final HomeSummary summary;

  const _ActiveGroupCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final membership = summary.membership;
    final group = summary.group;
    final progress = (group.memberCap != null && group.memberCap! > 0)
        ? (group.poolBalance / (membership.contributionAmount * group.memberCap!)).clamp(0.0, 1.0)
        : null;

    return GestureDetector(
      onTap: () => context.pushNamed(AppRoute.groupDetails.name, extra: membership.groupId),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.brandGreen, AppColors.accentGreen],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: [BoxShadow(color: AppColors.accentGreen.withValues(alpha: 0.25), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    membership.groupName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.spaceGrotesk(fontSize: 19, fontWeight: FontWeight.bold, color: AppColors.darkGreen),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    'Round ${group.currentCycleNumber}',
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.darkGreen),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '₦${formatAmount(membership.contributionAmount)} • ${membership.cycleFrequency?.label ?? '—'}',
              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.darkGreen.withValues(alpha: 0.8), fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                _statBlock('Members', '${summary.memberCount}'),
                const SizedBox(width: 24),
                _statBlock(
                  'Next payout',
                  group.nextPayoutDate != null ? formatShortDate(group.nextPayoutDate!) : 'TBD',
                ),
              ],
            ),
            if (progress != null) ...[
              const SizedBox(height: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.4),
                  color: AppColors.darkGreen,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '₦${formatAmount(group.poolBalance)} raised so far',
                style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.darkGreen.withValues(alpha: 0.75), fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statBlock(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.darkGreen.withValues(alpha: 0.7), fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(value, style: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.darkGreen)),
      ],
    );
  }
}

class _NoGroupCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: cardShadow(),
      ),
      child: EmptyState(
        icon: Icons.groups_rounded,
        title: 'No active groups.',
        subtitle: 'Join a group with an invite code, or start your own savings circle.',
        action: ElevatedButton(
          onPressed: () => context.pushNamed(AppRoute.joinOrCreate.name),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.brandGreen,
            foregroundColor: AppColors.darkGreen,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: Text('Join or Create a Group', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

/// Trailing card in the group carousel — always reachable by swiping past
/// the last group, so creating/joining another group isn't just an
/// onboarding-only action.
class _AddGroupCard extends StatelessWidget {
  const _AddGroupCard();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.pushNamed(AppRoute.joinOrCreate.name),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(color: AppColors.paleGreen, shape: BoxShape.circle),
              child: const Icon(Icons.add_rounded, color: AppColors.accentGreen, size: 26),
            ),
            const SizedBox(height: 12),
            Text(
              'Join or Create\nAnother Group',
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingInvitesBanner extends StatelessWidget {
  final int count;

  const _PendingInvitesBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.pushNamed(AppRoute.myInvites.name),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.infoPale, borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: Row(
          children: [
            const Icon(Icons.mail_rounded, color: AppColors.info, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                count == 1 ? "You've been invited to a group" : "You've been invited to $count groups",
                style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.info),
          ],
        ),
      ),
    );
  }
}

class _ReservedAccountCard extends StatelessWidget {
  final UserProfile profile;

  const _ReservedAccountCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: cardShadow(),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(color: AppColors.infoPale, shape: BoxShape.circle),
            child: const Icon(Icons.account_balance_rounded, color: AppColors.info, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reserved Account', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                  profile.personalReservedAccountBank ?? '—',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary),
                ),
                Text(
                  profile.personalReservedAccountNumber ?? '—',
                  style: GoogleFonts.spaceGrotesk(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              final number = profile.personalReservedAccountNumber;
              if (number == null) return;
              Clipboard.setData(ClipboardData(text: number));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Account number copied'), backgroundColor: AppColors.darkGreen),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.textSecondary),
          ),
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sharing coming soon'), backgroundColor: AppColors.darkGreen),
              );
            },
            icon: const Icon(Icons.ios_share_rounded, size: 18, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final bool hasGroup;
  final String? groupId;
  final bool isAdmin;

  const _QuickActions({required this.hasGroup, required this.groupId, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final actions = [
      (icon: Icons.payments_rounded, label: 'Contribute', color: AppColors.paleGreen, iconColor: AppColors.accentGreen),
      // Sending a direct invite is admin-only — members instead see a plain
      // "Members" tile pointing at the same Group Details screen.
      isAdmin
          ? (icon: Icons.person_add_alt_1_rounded, label: 'Invite Members', color: AppColors.infoPale, iconColor: AppColors.info)
          : (icon: Icons.people_alt_rounded, label: 'Members', color: AppColors.infoPale, iconColor: AppColors.info),
      (icon: Icons.chat_bubble_rounded, label: 'Group Chat', color: AppColors.warningPale, iconColor: AppColors.warning),
      (icon: Icons.info_outline_rounded, label: 'Group Details', color: AppColors.divider, iconColor: AppColors.textSecondary),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.6,
      children: List.generate(actions.length, (index) {
        final action = actions[index];
        return GestureDetector(
          onTap: !hasGroup ? () => context.pushNamed(AppRoute.joinOrCreate.name) : () => _handleTap(context, index, groupId!),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: cardShadow(opacity: 0.03)),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: action.color, shape: BoxShape.circle),
                  child: Icon(action.icon, color: action.iconColor, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    action.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  void _handleTap(BuildContext context, int index, String groupId) {
    switch (index) {
      case 0:
        context.pushNamed(AppRoute.contribution.name, extra: groupId);
        break;
      case 1:
        context.pushNamed(AppRoute.groupDetails.name, extra: groupId);
        break;
      case 2:
        context.pushNamed(AppRoute.groupChat.name, extra: groupId);
        break;
      case 3:
        context.pushNamed(AppRoute.groupDetails.name, extra: groupId);
        break;
    }
  }
}

class _UpcomingContributions extends StatelessWidget {
  final HomeSummary summary;

  const _UpcomingContributions({required this.summary});

  @override
  Widget build(BuildContext context) {
    final group = summary.group;
    final membership = summary.membership;

    // No contribution-schedule endpoint exists yet — project the next few
    // occurrences client-side from the group's cadence as a reasonable stand-in.
    final anchor = group.nextPayoutDate ?? DateTime.now().add(const Duration(days: 7));
    final dates = <DateTime>[anchor];
    for (var i = 1; i < 3; i++) {
      dates.add(_advance(dates.last, group.cycleFrequency));
    }

    return Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.xl), boxShadow: cardShadow()),
      child: Column(
        children: [
          for (var i = 0; i < dates.length; i++) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(color: AppColors.paleGreen, shape: BoxShape.circle),
                    child: const Icon(Icons.event_rounded, color: AppColors.accentGreen, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(formatFriendlyDate(dates[i]), style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        Text('₦${formatAmount(membership.contributionAmount)}', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  StatusPill(label: i == 0 ? 'Pending' : 'Upcoming', tone: i == 0 ? PillTone.warning : PillTone.neutral),
                ],
              ),
            ),
            if (i != dates.length - 1) Divider(height: 1, color: Colors.grey[100]),
          ],
        ],
      ),
    );
  }

  DateTime _advance(DateTime date, CycleFrequency? frequency) {
    switch (frequency) {
      case CycleFrequency.monthly:
        return DateTime(date.year, date.month + 1, date.day);
      case CycleFrequency.yearly:
        return DateTime(date.year + 1, date.month, date.day);
      case CycleFrequency.weekly:
      default:
        return date.add(const Duration(days: 7));
    }
  }
}

class _RecentActivity extends ConsumerWidget {
  const _RecentActivity();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(walletTransactionsControllerProvider);

    if (state.isLoading && state.items.isEmpty) {
      return Column(children: List.generate(3, (_) => const SkeletonListTile()));
    }

    if (state.items.isEmpty) {
      return const EmptyState(icon: Icons.history_rounded, title: 'No activity yet.', subtitle: 'Your contributions and payouts will show up here.');
    }

    final recent = state.items.take(5).toList();
    return Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.xl), boxShadow: cardShadow()),
      child: Column(
        children: [
          for (var i = 0; i < recent.length; i++) ...[
            _ActivityTile(transaction: recent[i]),
            if (i != recent.length - 1) Divider(height: 1, color: Colors.grey[100]),
          ],
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final WalletTransaction transaction;

  const _ActivityTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isCredit = transaction.isCredit;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: isCredit ? AppColors.paleGreen : AppColors.warningPale, shape: BoxShape.circle),
            child: Icon(
              isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              color: isCredit ? AppColors.accentGreen : AppColors.warning,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.narration?.isNotEmpty == true ? transaction.narration! : transaction.type,
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                Text(formatShortDate(transaction.createdAt), style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
          Text(
            '${isCredit ? '+' : '-'}₦${formatAmount(transaction.amount)}',
            style: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.bold, color: isCredit ? AppColors.accentGreen : AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}
