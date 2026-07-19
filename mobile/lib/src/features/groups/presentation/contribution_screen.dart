import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/pin_entry_sheet.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../../core/widgets/success_bottom_sheet.dart';
import '../../../routing/app_router.dart';
import '../../auth/data/user_repository.dart';
import '../../home/data/home_controller.dart';
import '../../shell/data/shell_tab_provider.dart';
import '../../wallet/data/wallet_controller.dart';
import '../data/contribution_status.dart';
import '../data/group_models.dart';
import '../data/group_repository.dart';

class ContributionScreen extends ConsumerStatefulWidget {
  final String groupId;

  const ContributionScreen({super.key, required this.groupId});

  @override
  ConsumerState<ContributionScreen> createState() => _ContributionScreenState();
}

class _ContributionScreenState extends ConsumerState<ContributionScreen> {
  GroupResponse? _group;
  bool _isLoading = true;
  bool _isPaying = false;
  bool _isGeneratingDirectPayment = false;
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
      final group = await ref.read(groupRepositoryProvider).getGroup(widget.groupId);
      await ref.read(walletTransactionsControllerProvider.notifier).refresh();
      setState(() {
        _group = group;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    }
  }

  bool get _hasPaidThisRound {
    final group = _group;
    if (group == null) return false;
    return hasPaidCurrentRound(group, ref.read(walletTransactionsControllerProvider).items);
  }

  Future<void> _payFromWallet() async {
    final pin = await PinEntrySheet.show(
      context,
      title: 'Confirm Contribution',
      subtitle: 'Enter your PIN to pay ₦${formatAmount(_group!.contributionAmount)} from your wallet.',
    );
    if (pin == null || !mounted) return;

    setState(() => _isPaying = true);
    try {
      await ref.read(groupRepositoryProvider).payFromWallet(widget.groupId, pin);
      await Future.wait([
        ref.read(userProfileControllerProvider.notifier).refresh(),
        ref.read(walletTransactionsControllerProvider.notifier).refresh(),
        ref.read(homeControllerProvider.notifier).refresh(),
      ]);

      if (!mounted) return;
      SuccessBottomSheet.show(
        context,
        title: 'Contribution Paid',
        subtitle: '₦${formatAmount(_group!.contributionAmount)} has been added to your group\'s pool.',
        primaryLabel: 'Done',
        onPrimary: () {
          Navigator.pop(context);
          context.pop();
        },
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message, style: TextStyle(color: Colors.white)), backgroundColor: AppColors.darkGreen));
    } finally {
      if (mounted) setState(() => _isPaying = false);
    }
  }

  Future<void> _payByBankTransfer() async {
    setState(() => _isGeneratingDirectPayment = true);
    try {
      final details = await ref.read(groupRepositoryProvider).generateDirectPayment(widget.groupId);
      if (!mounted) return;
      context.pushNamed(AppRoute.directPayment.name, extra: details);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message, style: TextStyle(color: Colors.white)), backgroundColor: AppColors.darkGreen));
    } finally {
      if (mounted) setState(() => _isGeneratingDirectPayment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileControllerProvider).profile;
    final balance = double.tryParse(profile?.walletBalance ?? '0') ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: Text('Contribute', style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Padding(padding: EdgeInsets.all(24), child: SkeletonCard(height: 260))
            : _error != null
                ? Center(child: Text(_error!, style: TextStyle(fontFamily: 'PlusJakartaSans', color: AppColors.textSecondary)))
                : _buildContent(balance),
      ),
    );
  }

  Widget _buildContent(double balance) {
    final group = _group!;
    final isGroupActive = group.status.toLowerCase() == 'active';
    final canPay = balance >= group.contributionAmount;
    final hasPaid = _hasPaidThisRound;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.brandGreen, AppColors.accentGreen], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(group.name, style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, color: AppColors.darkGreen.withValues(alpha: 0.8), fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text('₦${formatAmount(group.contributionAmount)}', style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.darkGreen)),
                Text('Round ${group.currentCycleNumber} • ${group.cycleFrequency?.label ?? '—'}', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, color: AppColors.darkGreen.withValues(alpha: 0.75))),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (hasPaid) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.paleGreen, borderRadius: BorderRadius.circular(AppRadius.lg)),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppColors.accentGreen, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "You've already contributed for this round. No need to pay again.",
                      style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, color: AppColors.darkGreen, fontWeight: FontWeight.w600, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (!isGroupActive) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.paleGreen, borderRadius: BorderRadius.circular(AppRadius.lg)),
              child: Row(
                children: [
                  const Icon(Icons.hourglass_empty_rounded, color: AppColors.accentGreen, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "This group hasn't started yet. The admin needs to start the rotation before contributions can be made.",
                      style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, color: AppColors.darkGreen, fontWeight: FontWeight.w600, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: cardShadow(opacity: 0.03)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Wallet balance', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                  Text('₦${formatAmount(balance)}', style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                ],
              ),
            ),
          ],
          const Spacer(),
          if (hasPaid || !isGroupActive) ...[
            const SizedBox.shrink(),
          ] else if (canPay) ...[
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isPaying ? null : _payFromWallet,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandGreen,
                  foregroundColor: AppColors.darkGreen,
                  disabledBackgroundColor: AppColors.brandGreen,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                ),
                child: _isPaying
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.darkGreen))
                    : Text('Pay from Wallet', style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: _isGeneratingDirectPayment ? null : _payByBankTransfer,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.darkGreen,
                  side: const BorderSide(color: AppColors.darkGreen, width: 1.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                ),
                child: _isGeneratingDirectPayment
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.darkGreen))
                    : Text('Pay by Bank Transfer', style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
          ] else ...[
            Text(
              "You don't have enough in your wallet for this contribution yet.",
              style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isGeneratingDirectPayment ? null : _payByBankTransfer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandGreen,
                  foregroundColor: AppColors.darkGreen,
                  disabledBackgroundColor: AppColors.brandGreen,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                ),
                child: _isGeneratingDirectPayment
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.darkGreen))
                    : Text('Pay by Bank Transfer', style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: () {
                  ref.read(selectedTabIndexProvider.notifier).state = 1;
                  context.goNamed(AppRoute.home.name);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.darkGreen,
                  side: const BorderSide(color: AppColors.darkGreen, width: 1.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                ),
                child: Text('Fund Wallet Instead', style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
