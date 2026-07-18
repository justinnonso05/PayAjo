import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../../core/widgets/status_pill.dart';
import '../../../routing/app_router.dart';
import '../data/group_models.dart';
import '../data/group_repository.dart';

class MyGroupsScreen extends ConsumerStatefulWidget {
  const MyGroupsScreen({super.key});

  @override
  ConsumerState<MyGroupsScreen> createState() => _MyGroupsScreenState();
}

class _MyGroupsScreenState extends ConsumerState<MyGroupsScreen> {
  List<UserGroupMembership> _groups = [];
  bool _isLoading = true;
  String? _error;

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
      final groups = await ref.read(groupRepositoryProvider).getMyGroups();
      setState(() {
        _groups = groups;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: Text('My Groups', style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        actions: [
          IconButton(
            onPressed: () => context.pushNamed(AppRoute.joinOrCreate.name),
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.textPrimary),
            tooltip: 'Join or create a group',
          ),
        ],
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: 3,
        itemBuilder: (context, index) => const Padding(padding: EdgeInsets.only(bottom: 16), child: SkeletonCard(height: 100)),
      );
    }

    if (_error != null) {
      return Center(child: Text(_error!, style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary)));
    }

    if (_groups.isEmpty) {
      return ListView(
        children: [
          EmptyState(
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
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      itemCount: _groups.length,
      itemBuilder: (context, index) {
        final group = _groups[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: GestureDetector(
            onTap: () => context.pushNamed(AppRoute.groupDetails.name, extra: group.groupId),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.xl), boxShadow: cardShadow()),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(color: AppColors.paleGreen, shape: BoxShape.circle),
                    child: const Icon(Icons.eco_rounded, color: AppColors.accentGreen),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(group.groupName, style: GoogleFonts.spaceGrotesk(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        const SizedBox(height: 2),
                        Text(
                          '₦${formatAmount(group.contributionAmount)} • ${group.cycleFrequency?.label ?? '—'}',
                          style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  StatusPill(label: group.isAdmin ? 'Admin' : 'Member', tone: group.isAdmin ? PillTone.info : PillTone.neutral),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
