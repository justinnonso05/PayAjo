import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../routing/app_router.dart';
import '../../../core/network/api_client.dart';
import '../data/auth_repository.dart';
import '../data/user_repository.dart';
import 'widgets/numeric_keypad.dart';
import 'widgets/pin_dots_indicator.dart';

class ConfirmPinScreen extends ConsumerStatefulWidget {
  final String pin;

  const ConfirmPinScreen({super.key, required this.pin});

  @override
  ConsumerState<ConfirmPinScreen> createState() => _ConfirmPinScreenState();
}

class _ConfirmPinScreenState extends ConsumerState<ConfirmPinScreen> {
  String _digits = '';
  int _shakeTick = 0;
  bool _isSubmitting = false;

  void _onDigit(String digit) {
    if (_isSubmitting || _digits.length >= kPinLength) return;
    setState(() => _digits += digit);

    if (_digits.length == kPinLength) {
      _handleComplete();
    }
  }

  void _onBackspace() {
    if (_isSubmitting || _digits.isEmpty) return;
    setState(() => _digits = _digits.substring(0, _digits.length - 1));
  }

  Future<void> _handleComplete() async {
    if (_digits != widget.pin) {
      setState(() => _shakeTick++);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("PINs don't match. Try again.", style: TextStyle(color: Colors.white)),
          backgroundColor: Color(0xFF1D3108),
        ),
      );
      Future.delayed(const Duration(milliseconds: 400), () {
        if (!mounted) return;
        setState(() => _digits = '');
      });
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ref.read(authRepositoryProvider).setupPin(_digits);
      ref.invalidate(userProfileControllerProvider);

      if (!mounted) return;
      context.goNamed(AppRoute.home.name);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message, style: TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF1D3108)),
      );
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
            Text(
              'Confirm your PIN',
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
                'Enter your PIN again to confirm.',
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
            PinDotsIndicator(filledCount: _digits.length, shakeTick: _shakeTick),
            if (_isSubmitting) ...[
              const SizedBox(height: 24),
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF1D3108)),
              ),
            ],
            const Spacer(),
            NumericKeypad(onDigit: _onDigit, onBackspace: _onBackspace),
            const SizedBox(height: 16 + 14 + 16),
          ],
        ),
      ),
    );
  }
}
