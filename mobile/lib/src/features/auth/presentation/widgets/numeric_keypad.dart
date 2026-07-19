import 'package:flutter/material.dart';

/// Large circular numeric keypad used by PIN entry screens.
/// Calls [onDigit] with '0'-'9' for digit taps, and [onBackspace] on delete.
class NumericKeypad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  const NumericKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
  });

  static const List<List<String>> _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in _rows) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: row.map((digit) => _KeypadButton(label: digit, onTap: () => onDigit(digit))).toList(),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const SizedBox(width: 72, height: 72),
            _KeypadButton(label: '0', onTap: () => onDigit('0')),
            _KeypadButton(
              icon: Icons.backspace_outlined,
              onTap: onBackspace,
              isSecondary: true,
            ),
          ],
        ),
      ],
    );
  }
}

class _KeypadButton extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool isSecondary;

  const _KeypadButton({
    this.label,
    this.icon,
    required this.onTap,
    this.isSecondary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSecondary ? Colors.transparent : const Color(0xFFF3F4F6),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 72,
          height: 72,
          child: Center(
            child: icon != null
                ? Icon(icon, color: const Color(0xFF1D3108), size: 26)
                : Text(
                    label!,
                    style: TextStyle(fontFamily: 'SpaceGrotesk', 
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1D3108),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
