import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

enum PillTone { success, warning, danger, info, neutral }

class StatusPill extends StatelessWidget {
  final String label;
  final PillTone tone;

  const StatusPill({super.key, required this.label, this.tone = PillTone.neutral});

  (Color, Color) get _colors {
    switch (tone) {
      case PillTone.success:
        return (AppColors.paleGreen, AppColors.accentGreen);
      case PillTone.warning:
        return (AppColors.warningPale, AppColors.warning);
      case PillTone.danger:
        return (AppColors.dangerPale, AppColors.danger);
      case PillTone.info:
        return (AppColors.infoPale, AppColors.info);
      case PillTone.neutral:
        return (AppColors.divider, AppColors.textSecondary);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}
