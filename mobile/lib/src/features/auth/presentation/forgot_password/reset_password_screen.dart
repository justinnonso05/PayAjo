import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../routing/app_router.dart';
import '../../data/auth_repository.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({required this.email, super.key});

  final String email;

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isSubmitting = false;
  bool _isResending = false;

  @override
  void dispose() {
    _otpController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _validateOtp(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.length < 4) return 'Enter the code from your email';
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Password is required';
    if (password.length < 8) return 'Password must be at least 8 characters';
    return null;
  }

  String? _validateConfirm(String? value) {
    if (value != _passwordController.text) return "Passwords don't match";
    return null;
  }

  Future<void> _resend() async {
    setState(() => _isResending = true);
    try {
      await ref.read(authRepositoryProvider).requestPasswordReset(email: widget.email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Code resent to your email', style: TextStyle(color: Colors.white)), backgroundColor: AppColors.darkGreen),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message, style: const TextStyle(color: Colors.white)), backgroundColor: AppColors.darkGreen),
      );
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);
    try {
      await ref.read(authRepositoryProvider).resetPasswordWithOtp(
            email: widget.email,
            otpCode: _otpController.text.trim(),
            newPassword: _passwordController.text,
          );
      if (!mounted) return;
      context.goNamed(AppRoute.passwordResetSuccess.name);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message, style: const TextStyle(color: Colors.white)), backgroundColor: AppColors.darkGreen),
      );
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reset Your Password', style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                Text(
                  'Enter the code sent to ${widget.email} and choose a new password.',
                  style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 14, color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 28),
                Text('Code', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  validator: _validateOtp,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 8, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '••••••',
                    hintStyle: const TextStyle(color: AppColors.hint, letterSpacing: 8),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border, width: 1.2)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border, width: 1.2)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.darkGreen, width: 1.5)),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isResending ? null : _resend,
                    child: Text(
                      _isResending ? 'Sending…' : "Didn't get it? Resend code",
                      style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.accentGreen),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text('New password', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  validator: _validatePassword,
                  style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'At least 8 characters',
                    hintStyle: const TextStyle(color: AppColors.hint),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.hint, size: 20),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border, width: 1.2)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border, width: 1.2)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.darkGreen, width: 1.5)),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Confirm password', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _confirmController,
                  obscureText: _obscureConfirm,
                  validator: _validateConfirm,
                  style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Re-enter your new password',
                    hintStyle: const TextStyle(color: AppColors.hint),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.hint, size: 20),
                      onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border, width: 1.2)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border, width: 1.2)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.darkGreen, width: 1.5)),
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandGreen,
                      foregroundColor: AppColors.darkGreen,
                      disabledBackgroundColor: AppColors.brandGreen,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.darkGreen))
                        : const Text('Reset Password', style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
