import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../routing/app_router.dart';
import '../../data/auth_repository.dart';

class RequestPinResetScreen extends ConsumerStatefulWidget {
  const RequestPinResetScreen({super.key});

  @override
  ConsumerState<RequestPinResetScreen> createState() => _RequestPinResetScreenState();
}

class _RequestPinResetScreenState extends ConsumerState<RequestPinResetScreen> {
  bool _isSubmitting = false;

  Future<void> _sendCode() async {
    setState(() => _isSubmitting = true);
    try {
      await ref.read(authRepositoryProvider).requestPinReset();
      if (!mounted) return;
      context.pushNamed(AppRoute.verifyPinResetOtp.name);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.darkGreen));
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
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(color: AppColors.paleGreen, shape: BoxShape.circle),
                child: const Icon(Icons.mail_lock_outlined, color: AppColors.accentGreen, size: 28),
              ),
              const SizedBox(height: 20),
              Text('Reset Your PIN', style: GoogleFonts.spaceGrotesk(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Text(
                "We'll send a one-time code to your registered email to verify it's you before setting a new PIN.",
                style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _sendCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandGreen,
                    foregroundColor: AppColors.darkGreen,
                    disabledBackgroundColor: AppColors.brandGreen,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.darkGreen))
                      : Text('Send Code', style: GoogleFonts.spaceGrotesk(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
