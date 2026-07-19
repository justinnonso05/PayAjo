import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../routing/app_router.dart';
import 'widgets/numeric_keypad.dart';
import 'widgets/pin_dots_indicator.dart';

class CreatePinScreen extends StatefulWidget {
  const CreatePinScreen({super.key});

  @override
  State<CreatePinScreen> createState() => _CreatePinScreenState();
}

class _CreatePinScreenState extends State<CreatePinScreen> {
  String _digits = '';

  void _onDigit(String digit) {
    if (_digits.length >= kPinLength) return;
    setState(() => _digits += digit);

    if (_digits.length == kPinLength) {
      final pin = _digits;
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!mounted) return;
        context.pushNamed(AppRoute.confirmPin.name, extra: pin);
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
            Text(
              'Set your 4-digit transaction PIN',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'SpaceGrotesk', 
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1D3108),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                "You'll only be asked for this once. You'll use it to approve transactions and log in quickly.",
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'PlusJakartaSans', 
                  fontSize: 14,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 48),
            PinDotsIndicator(filledCount: _digits.length),
            const Spacer(),
            NumericKeypad(onDigit: _onDigit, onBackspace: _onBackspace),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.goNamed(AppRoute.home.name),
              child: Text(
                'Not now',
                style: TextStyle(fontFamily: 'PlusJakartaSans', 
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[500],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
