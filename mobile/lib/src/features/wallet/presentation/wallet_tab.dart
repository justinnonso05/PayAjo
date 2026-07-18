import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/pin_entry_sheet.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../../core/widgets/success_bottom_sheet.dart';
import '../../auth/data/user_profile.dart';
import '../../auth/data/user_repository.dart';
import '../data/wallet_controller.dart';
import '../data/wallet_models.dart';
import '../data/wallet_repository.dart';

class WalletTab extends ConsumerStatefulWidget {
  const WalletTab({super.key});

  @override
  ConsumerState<WalletTab> createState() => _WalletTabState();
}

class _WalletTabState extends ConsumerState<WalletTab> {
  bool _isWithdrawing = false;

  Future<void> _handleWithdraw() async {
    final profile = ref.read(userProfileControllerProvider).profile;
    if (profile == null) return;

    final amountController = TextEditingController();
    final amount = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(sheetContext).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Withdraw', style: GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text(
              'Available balance: ₦${formatAmount(double.tryParse(profile.walletBalance) ?? 0)}',
              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                prefixText: '₦ ',
                hintText: '0.00',
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.darkGreen, width: 1.5)),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  final value = double.tryParse(amountController.text.trim());
                  if (value == null || value <= 0) return;
                  Navigator.pop(sheetContext, value);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandGreen,
                  foregroundColor: AppColors.darkGreen,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                ),
                child: Text('Continue', style: GoogleFonts.spaceGrotesk(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );

    if (amount == null || !mounted) return;

    final pin = await PinEntrySheet.show(
      context,
      title: 'Confirm Withdrawal',
      subtitle: 'Enter your PIN to withdraw ₦${formatAmount(amount)}.',
    );
    if (pin == null || !mounted) return;

    setState(() => _isWithdrawing = true);
    try {
      await ref.read(walletRepositoryProvider).withdraw(amount: amount, pin: pin);
      await ref.read(userProfileControllerProvider.notifier).refresh();
      await ref.read(walletTransactionsControllerProvider.notifier).refresh();

      if (!mounted) return;
      SuccessBottomSheet.show(
        context,
        title: 'Withdrawal Successful',
        subtitle: '₦${formatAmount(amount)} is on its way to your payout bank.',
        primaryLabel: 'Done',
        onPrimary: () => Navigator.pop(context),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.darkGreen));
    } finally {
      if (mounted) setState(() => _isWithdrawing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(userProfileControllerProvider);
    final txState = ref.watch(walletTransactionsControllerProvider);
    final profile = profileState.profile;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppColors.accentGreen,
        onRefresh: () async {
          await Future.wait([
            ref.read(userProfileControllerProvider.notifier).refresh(),
            ref.read(walletTransactionsControllerProvider.notifier).refresh(),
          ]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
          children: [
            Text('Wallet', style: GoogleFonts.spaceGrotesk(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 20),
            if (profile == null)
              const SkeletonCard(height: 180)
            else
              _BalanceCard(
                balance: double.tryParse(profile.walletBalance) ?? 0,
                isBusy: _isWithdrawing,
                onWithdraw: _handleWithdraw,
              ),
            const SizedBox(height: 24),
            if (profile?.personalReservedAccountNumber != null) ...[
              const SectionHeader(title: 'Virtual Account'),
              const SizedBox(height: 12),
              _VirtualAccountCard(profile: profile!),
              const SizedBox(height: 24),
              const SectionHeader(title: 'Funding Methods'),
              const SizedBox(height: 12),
              _FundingMethods(profile: profile),
              const SizedBox(height: 28),
            ],
            const SectionHeader(title: 'Transaction History'),
            const SizedBox(height: 12),
            _TransactionHistory(state: txState),
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final double balance;
  final bool isBusy;
  final VoidCallback onWithdraw;

  const _BalanceCard({required this.balance, required this.isBusy, required this.onWithdraw});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.darkGreen, Color(0xFF2E5211)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [BoxShadow(color: AppColors.darkGreen.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('WALLET BALANCE', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
          const SizedBox(height: 10),
          Text('₦${formatAmount(balance)}', style: GoogleFonts.spaceGrotesk(fontSize: 32, color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(child: _actionButton('Add Money', Icons.add_rounded, () => _showAddMoneyHint(context))),
              const SizedBox(width: 10),
              Expanded(child: _actionButton('Withdraw', Icons.arrow_upward_rounded, isBusy ? null : onWithdraw)),
              const SizedBox(width: 10),
              Expanded(child: _actionButton('Transfer', Icons.swap_horiz_rounded, () => _showComingSoon(context))),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddMoneyHint(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transfer to your virtual account below to fund your wallet'), backgroundColor: AppColors.darkGreen),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Wallet-to-wallet transfer is coming soon'), backgroundColor: AppColors.darkGreen),
    );
  }

  Widget _actionButton(String label, IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(height: 6),
            Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

class _VirtualAccountCard extends StatelessWidget {
  final UserProfile profile;

  const _VirtualAccountCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.xl), boxShadow: cardShadow()),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile.personalReservedAccountBank ?? '—', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text(profile.personalReservedAccountNumber ?? '—', style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(profile.personalReservedAccountName ?? '—', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              final number = profile.personalReservedAccountNumber;
              if (number == null) return;
              Clipboard.setData(ClipboardData(text: number));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account number copied'), backgroundColor: AppColors.darkGreen));
            },
            icon: const Icon(Icons.copy_rounded, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _FundingMethods extends StatelessWidget {
  final UserProfile profile;

  const _FundingMethods({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _methodTile(
          icon: Icons.account_balance_rounded,
          title: 'Fund wallet via bank transfer',
          subtitle: 'Send money to your personal virtual account above — it lands in your wallet automatically.',
        ),
        const SizedBox(height: 10),
        _methodTile(
          icon: Icons.bolt_rounded,
          title: 'Pay contributions from wallet',
          subtitle: 'When your balance covers a contribution, pay in one tap instead of transferring to the group directly.',
        ),
      ],
    );
  }

  Widget _methodTile({required IconData icon, required String title, required String subtitle}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: cardShadow(opacity: 0.03)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(color: AppColors.paleGreen, shape: BoxShape.circle),
            child: Icon(icon, color: AppColors.accentGreen, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionHistory extends StatelessWidget {
  final WalletTransactionsState state;

  const _TransactionHistory({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && state.items.isEmpty) {
      return Column(children: List.generate(4, (_) => const SkeletonListTile()));
    }

    if (state.error != null && state.items.isEmpty) {
      return EmptyState(icon: Icons.wifi_off_rounded, title: "Couldn't load transactions", subtitle: state.error);
    }

    if (state.items.isEmpty) {
      return const EmptyState(icon: Icons.receipt_long_rounded, title: 'No transactions yet.', subtitle: 'Deposits, withdrawals, and contributions will show up here.');
    }

    return Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.xl), boxShadow: cardShadow()),
      child: Column(
        children: [
          for (var i = 0; i < state.items.length; i++) ...[
            _TransactionTile(transaction: state.items[i]),
            if (i != state.items.length - 1) Divider(height: 1, color: Colors.grey[100]),
          ],
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final WalletTransaction transaction;

  const _TransactionTile({required this.transaction});

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
            child: Icon(isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, color: isCredit ? AppColors.accentGreen : AppColors.warning, size: 18),
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
                Text('${formatShortDate(transaction.createdAt)} · ${formatTime(transaction.createdAt)}', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textMuted)),
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
