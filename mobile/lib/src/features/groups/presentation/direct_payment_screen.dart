import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/success_bottom_sheet.dart';
import '../../auth/data/user_repository.dart';
import '../../home/data/home_controller.dart';
import '../../wallet/data/wallet_controller.dart';
import '../../wallet/data/wallet_repository.dart';
import '../data/group_models.dart';

/// Shows a one-time virtual account for paying a contribution directly by
/// bank transfer. The account expires after [DirectPaymentDetails.accountDurationSeconds]
/// (currently 40 minutes); this screen counts that down and polls the
/// transaction-status endpoint so it can auto-advance to a success state
/// once the Monnify webhook lands.
class DirectPaymentScreen extends ConsumerStatefulWidget {
  final DirectPaymentDetails details;

  const DirectPaymentScreen({super.key, required this.details});

  @override
  ConsumerState<DirectPaymentScreen> createState() => _DirectPaymentScreenState();
}

class _DirectPaymentScreenState extends ConsumerState<DirectPaymentScreen> {
  late Duration _remaining;
  Timer? _countdownTimer;
  Timer? _pollTimer;
  bool _expired = false;
  bool _confirmed = false;

  @override
  void initState() {
    super.initState();
    _remaining = widget.details.expiresOn.difference(DateTime.now());
    if (_remaining.isNegative) _remaining = Duration.zero;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tickCountdown());
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _pollStatus());
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  void _tickCountdown() {
    final remaining = widget.details.expiresOn.difference(DateTime.now());
    if (!mounted) return;
    setState(() {
      _remaining = remaining.isNegative ? Duration.zero : remaining;
      if (_remaining == Duration.zero) _expired = true;
    });
    if (_expired) _countdownTimer?.cancel();
  }

  Future<void> _pollStatus() async {
    if (_confirmed || _expired) return;
    final successful = await ref.read(walletRepositoryProvider).isTransactionSuccessful(widget.details.paymentReference);
    if (!mounted || !successful) return;

    _confirmed = true;
    _countdownTimer?.cancel();
    _pollTimer?.cancel();

    await Future.wait([
      ref.read(userProfileControllerProvider.notifier).refresh(),
      ref.read(walletTransactionsControllerProvider.notifier).refresh(),
      ref.read(homeControllerProvider.notifier).refresh(),
    ]);

    if (!mounted) return;
    SuccessBottomSheet.show(
      context,
      title: 'Contribution Received',
      subtitle: '₦${formatAmount(widget.details.amount)} has been added to your group\'s pool.',
      primaryLabel: 'Done',
      onPrimary: () {
        Navigator.pop(context);
        context.pop();
        context.pop();
      },
    );
  }

  String _formatRemaining(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _copy(String value, String label) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied', style: TextStyle(color: Colors.white)), backgroundColor: AppColors.darkGreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.details;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: Text('Pay by Bank Transfer', style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _expired ? AppColors.dangerPale : AppColors.paleGreen,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                alignment: Alignment.center,
                child: Text(
                  _expired ? 'This account has expired' : 'Expires in ${_formatRemaining(_remaining)}',
                  style: TextStyle(fontFamily: 'SpaceGrotesk', 
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _expired ? AppColors.danger : AppColors.accentGreen,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.xl), boxShadow: cardShadow(opacity: 0.04)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Transfer exactly', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('₦${formatAmount(d.amount)}', style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    const SizedBox(height: 20),
                    _DetailRow(label: 'Bank', value: d.bankName),
                    const SizedBox(height: 14),
                    _DetailRow(
                      label: 'Account Number',
                      value: d.accountNumber,
                      onTap: () => _copy(d.accountNumber, 'Account number'),
                    ),
                    const SizedBox(height: 14),
                    _DetailRow(label: 'Account Name', value: d.accountName),
                  ],
                ),
              ),
              if (d.checkoutUrl.isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.xl), boxShadow: cardShadow(opacity: 0.04)),
                  child: Column(
                    children: [
                      Text('Or scan to pay another way', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('Card, USSD, or transfer via Monnify checkout', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11.5, color: AppColors.textMuted)),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.border)),
                        child: QrImageView(
                          data: d.checkoutUrl,
                          version: QrVersions.auto,
                          size: 160,
                          backgroundColor: Colors.white,
                          eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.darkGreen),
                          dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: AppColors.darkGreen),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Text(
                'This account is generated just for this contribution and can only be used once. Send exactly ₦${formatAmount(d.amount)} from any bank app before it expires. We\'ll confirm automatically once it lands.',
                style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentGreen),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Waiting for payment…',
                      style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline_rounded, size: 13, color: AppColors.textMuted),
                    const SizedBox(width: 5),
                    Text(
                      'Secured & powered by Monnify',
                      style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11.5, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _DetailRow({required this.label, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
        GestureDetector(
          onTap: onTap,
          child: Row(
            children: [
              Text(value, style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              if (onTap != null) ...[
                const SizedBox(width: 6),
                const Icon(Icons.copy_rounded, size: 16, color: AppColors.accentGreen),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
