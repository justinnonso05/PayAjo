import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/success_bottom_sheet.dart';
import '../../../routing/app_router.dart';
import '../../auth/data/user_repository.dart';
import '../data/wallet_repository.dart';

class PayoutBankOtpScreen extends ConsumerStatefulWidget {
  final String bankCode;
  final String bankName;
  final String accountNumber;
  final String accountName;

  const PayoutBankOtpScreen({
    super.key,
    required this.bankCode,
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
  });

  @override
  ConsumerState<PayoutBankOtpScreen> createState() => _PayoutBankOtpScreenState();
}

class _PayoutBankOtpScreenState extends ConsumerState<PayoutBankOtpScreen> {
  final _otpController = TextEditingController();
  bool _isSubmitting = false;
  bool _isResending = false;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _resend() async {
    setState(() => _isResending = true);
    try {
      await ref.read(walletRepositoryProvider).requestPayoutBankOtp();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Code resent to your email', style: TextStyle(color: Colors.white)), backgroundColor: AppColors.darkGreen),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message, style: TextStyle(color: Colors.white)), backgroundColor: AppColors.darkGreen));
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _confirm() async {
    final otp = _otpController.text.trim();
    if (otp.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the code from your email', style: TextStyle(color: Colors.white)), backgroundColor: AppColors.darkGreen),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(walletRepositoryProvider).setPayoutBank(
            bankAccountNumber: widget.accountNumber,
            bankCode: widget.bankCode,
            otpCode: otp,
          );
      ref.invalidate(userProfileControllerProvider);

      if (!mounted) return;
      SuccessBottomSheet.show(
        context,
        title: 'Payout Bank Set',
        subtitle: 'Withdrawals will now go straight to ${widget.accountName} at ${widget.bankName}.',
        primaryLabel: 'Done',
        onPrimary: () {
          Navigator.pop(context);
          context.goNamed(AppRoute.home.name);
        },
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message, style: TextStyle(color: Colors.white)), backgroundColor: AppColors.darkGreen));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, iconTheme: const IconThemeData(color: AppColors.textPrimary)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Confirm It\'s You', style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Text(
                'Enter the code we emailed you to confirm ${widget.accountName} (${widget.bankName}) as your payout account.',
                style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 14, color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 10, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '••••••',
                  hintStyle: const TextStyle(color: AppColors.hint, letterSpacing: 10),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border, width: 1.2)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border, width: 1.2)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.darkGreen, width: 1.5)),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _isResending ? null : _resend,
                  child: Text(
                    _isResending ? 'Sending…' : "Didn't get it? Resend code",
                    style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.accentGreen),
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _confirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandGreen,
                    foregroundColor: AppColors.darkGreen,
                    disabledBackgroundColor: AppColors.brandGreen,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.darkGreen))
                      : Text('Confirm', style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
