import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../routing/app_router.dart';
import '../../data/auth_repository.dart';
import '../widgets/numeric_keypad.dart';
import '../widgets/pin_dots_indicator.dart';

class ResetConfirmPinScreen extends ConsumerStatefulWidget {
  final String otpCode;
  final String pin;

  const ResetConfirmPinScreen({super.key, required this.otpCode, required this.pin});

  @override
  ConsumerState<ResetConfirmPinScreen> createState() => _ResetConfirmPinScreenState();
}

class _ResetConfirmPinScreenState extends ConsumerState<ResetConfirmPinScreen> {
  String _digits = '';
  int _shakeTick = 0;
  bool _isSubmitting = false;

  void _onDigit(String digit) {
    if (_isSubmitting || _digits.length >= kPinLength) return;
    setState(() => _digits += digit);
    if (_digits.length == kPinLength) _handleComplete();
  }

  void _onBackspace() {
    if (_isSubmitting || _digits.isEmpty) return;
    setState(() => _digits = _digits.substring(0, _digits.length - 1));
  }

  Future<void> _handleComplete() async {
    if (_digits != widget.pin) {
      setState(() => _shakeTick++);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("PINs don't match. Try again."), backgroundColor: AppColors.darkGreen),
      );
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) setState(() => _digits = '');
      });
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(authRepositoryProvider).resetPin(otpCode: widget.otpCode, newPin: _digits);
      if (!mounted) return;
      context.pushReplacementNamed(AppRoute.pinResetSuccess.name);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.darkGreen));
      setState(() {
        _isSubmitting = false;
        _digits = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            Text('Confirm New PIN', style: GoogleFonts.spaceGrotesk(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Enter your new PIN again to confirm.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w500, height: 1.4),
              ),
            ),
            const SizedBox(height: 48),
            PinDotsIndicator(filledCount: _digits.length, shakeTick: _shakeTick),
            if (_isSubmitting) ...[
              const SizedBox(height: 24),
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.darkGreen)),
            ],
            const Spacer(),
            NumericKeypad(onDigit: _onDigit, onBackspace: _onBackspace),
            const SizedBox(height: 46),
          ],
        ),
      ),
    );
  }
}
