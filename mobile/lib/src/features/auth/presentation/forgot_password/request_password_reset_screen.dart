import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../routing/app_router.dart';
import '../../data/auth_repository.dart';

class RequestPasswordResetScreen extends ConsumerStatefulWidget {
  const RequestPasswordResetScreen({super.key});

  @override
  ConsumerState<RequestPasswordResetScreen> createState() => _RequestPasswordResetScreenState();
}

class _RequestPasswordResetScreenState extends ConsumerState<RequestPasswordResetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isSubmitting = false;

  static final RegExp _emailRegExp = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Email is required';
    if (!_emailRegExp.hasMatch(trimmed)) return 'Enter a valid email address';
    return null;
  }

  Future<void> _sendCode() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);
    final email = _emailController.text.trim();
    try {
      await ref.read(authRepositoryProvider).requestPasswordReset(email: email);
      if (!mounted) return;
      context.pushNamed(AppRoute.resetPassword.name, extra: email);
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(color: AppColors.paleGreen, shape: BoxShape.circle),
                  child: const Icon(Icons.lock_reset_outlined, color: AppColors.accentGreen, size: 28),
                ),
                const SizedBox(height: 20),
                Text('Forgot Password?', style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                Text(
                  "Enter the email on your account and we'll send a one-time code to reset your password.",
                  style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 14, color: AppColors.textSecondary, height: 1.5),
                ),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                  style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'you@example.com',
                    hintStyle: const TextStyle(color: AppColors.hint),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border, width: 1.2)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border, width: 1.2)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.darkGreen, width: 1.5)),
                  ),
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
                        : const Text('Send Code', style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 15, fontWeight: FontWeight.bold)),
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
