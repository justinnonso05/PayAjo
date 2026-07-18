import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../routing/app_router.dart';
import '../widgets/numeric_keypad.dart';
import '../widgets/pin_dots_indicator.dart';

class ResetNewPinScreen extends StatefulWidget {
  final String otpCode;

  const ResetNewPinScreen({super.key, required this.otpCode});

  @override
  State<ResetNewPinScreen> createState() => _ResetNewPinScreenState();
}

class _ResetNewPinScreenState extends State<ResetNewPinScreen> {
  String _digits = '';

  void _onDigit(String digit) {
    if (_digits.length >= kPinLength) return;
    setState(() => _digits += digit);
    if (_digits.length == kPinLength) {
      final pin = _digits;
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!mounted) return;
        context.pushNamed(AppRoute.resetConfirmPin.name, extra: {'otp': widget.otpCode, 'pin': pin});
      });
    }
  }

  void _onBackspace() {
    if (_digits.isEmpty) return;
    setState(() => _digits = _digits.substring(0, _digits.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            Text('Enter New PIN', style: GoogleFonts.spaceGrotesk(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Choose a new 4-digit PIN for your account.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w500, height: 1.4),
              ),
            ),
            const SizedBox(height: 48),
            PinDotsIndicator(filledCount: _digits.length),
            const Spacer(),
            NumericKeypad(onDigit: _onDigit, onBackspace: _onBackspace),
            const SizedBox(height: 46),
          ],
        ),
      ),
    );
  }
}
