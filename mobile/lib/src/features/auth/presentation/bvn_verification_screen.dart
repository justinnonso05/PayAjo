import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../routing/app_router.dart';
import '../../../core/network/api_client.dart';
import '../data/user_repository.dart';

class BvnVerificationScreen extends ConsumerStatefulWidget {
  const BvnVerificationScreen({super.key});

  @override
  ConsumerState<BvnVerificationScreen> createState() => _BvnVerificationScreenState();
}

class _BvnVerificationScreenState extends ConsumerState<BvnVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bvnController = TextEditingController();
  bool _isVerifying = false;

  @override
  void dispose() {
    _bvnController.dispose();
    super.dispose();
  }

  String? _validateBvn(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'BVN is required';
    }
    if (trimmed.length != 11) {
      return 'BVN must be 11 digits';
    }
    return null;
  }

  Future<void> _handleContinue() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isVerifying = true;
    });

    try {
      final profile = await ref.read(userRepositoryProvider).mockVerifyKyc(_bvnController.text.trim());
      ref.read(currentUserProvider.notifier).state = profile;

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('BVN verified successfully!', style: TextStyle(color: Colors.white)),
          backgroundColor: Color(0xFF1D3108),
        ),
      );

      context.goNamed(AppRoute.joinOrCreate.name);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message, style: const TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF1D3108),
        ),
      );
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bottomPadding = MediaQuery.of(context).padding.bottom;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24.0, 24.0, 24.0, bottomPadding + 16.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - (32.0 + bottomPadding),
                ),
                child: IntrinsicHeight(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),

                        // Title & Subtitle
                        Text(
                          'Secure Your Account',
                          style: TextStyle(fontFamily: 'SpaceGrotesk', 
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1D3108),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'To keep every savings group secure, we need to verify your identity.',
                          style: TextStyle(fontFamily: 'PlusJakartaSans', 
                            fontSize: 15,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 36),

                        // BVN Field
                        Text(
                          'BVN',
                          style: TextStyle(fontFamily: 'PlusJakartaSans', 
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1D3108),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _bvnController,
                          keyboardType: TextInputType.number,
                          maxLength: 11,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          validator: _validateBvn,
                          style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF1D3108)),
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: '12345678901',
                            hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14, fontWeight: FontWeight.w400),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1.2),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1.2),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFF1D3108), width: 1.5),
                            ),
                          ),
                        ),

                        // Spacer to push button group to the bottom
                        const Spacer(),
                        const SizedBox(height: 24),

                        // Security notice
                        Align(
                          alignment: Alignment.center,
                          child: Text(
                            'Your BVN is used only to verify your identity and\nis never shared with other group members.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontFamily: 'PlusJakartaSans', 
                              fontSize: 11,
                              color: Colors.grey[400],
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Continue Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isVerifying ? null : _handleContinue,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFACEC87),
                              foregroundColor: const Color(0xFF1D3108),
                              disabledBackgroundColor: const Color(0xFFACEC87),
                              disabledForegroundColor: const Color(0xFF1D3108),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                            ),
                            child: _isVerifying
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Color(0xFF1D3108),
                                    ),
                                  )
                                : Text(
                                    'Continue',
                                    style: TextStyle(fontFamily: 'SpaceGrotesk', 
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
