import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../features/auth/presentation/widgets/numeric_keypad.dart';
import '../../features/auth/presentation/widgets/pin_dots_indicator.dart';
import '../theme/app_colors.dart';

/// Modal PIN entry used to authorize an action (withdraw, pay from wallet,
/// etc). Resolves with the 4-digit PIN once entered, or null if dismissed.
class PinEntrySheet extends StatefulWidget {
  final String title;
  final String subtitle;

  const PinEntrySheet({super.key, required this.title, required this.subtitle});

  static Future<String?> show(
    BuildContext context, {
    String title = 'Enter your PIN',
    String subtitle = 'Confirm this action with your transaction PIN.',
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => PinEntrySheet(title: title, subtitle: subtitle),
    );
  }

  @override
  State<PinEntrySheet> createState() => _PinEntrySheetState();
}

class _PinEntrySheetState extends State<PinEntrySheet> {
  String _digits = '';

  void _onDigit(String digit) {
    if (_digits.length >= kPinLength) return;
    setState(() => _digits += digit);
    if (_digits.length == kPinLength) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) Navigator.pop(context, _digits);
      });
    }
  }

  void _onBackspace() {
    if (_digits.isEmpty) return;
    setState(() => _digits = _digits.substring(0, _digits.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 28, 24, MediaQuery.of(context).padding.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.grey),
              ),
            ],
          ),
          Text(
            widget.subtitle,
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 28),
          PinDotsIndicator(filledCount: _digits.length),
          const SizedBox(height: 24),
          NumericKeypad(onDigit: _onDigit, onBackspace: _onBackspace),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
