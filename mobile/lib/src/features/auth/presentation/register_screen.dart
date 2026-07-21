import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../routing/app_router.dart';
import '../data/auth_repository.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/notification_service.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _agreeToTerms = false;
  bool _obscurePassword = true;
  bool _isSubmitting = false;

  static final RegExp _emailRegExp = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final RegExp _phoneRegExp = RegExp(r'^\+?[0-9]{7,15}$');

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateRequired(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Email is required';
    }
    if (!_emailRegExp.hasMatch(trimmed)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? _validateUsername(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Username is required';
    }
    if (trimmed.length < 3) {
      return 'Username must be at least 3 characters';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Phone number is required';
    }
    if (!_phoneRegExp.hasMatch(trimmed)) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) {
      return 'Password is required';
    }
    if (password.length < 8) {
      return 'Password must be at least 8 characters';
    }
    return null;
  }

  Future<void> _handleSignUp() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }
    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please agree to the Terms & Conditions to continue.', style: TextStyle(color: Colors.white)),
          backgroundColor: Color(0xFF1D3108),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ref.read(authRepositoryProvider).register(
            RegisterRequest(
              email: _emailController.text.trim(),
              username: _usernameController.text.trim(),
              firstName: _firstNameController.text.trim(),
              lastName: _lastNameController.text.trim(),
              password: _passwordController.text,
              phone: _phoneController.text.trim(),
              // Passed at signup so the welcome push notification has a
              // token to send to immediately, instead of racing the
              // post-login token-sync call that happens moments later.
              fcmToken: NotificationService().currentToken,
            ),
          );

      if (!mounted) return;
      context.goNamed(AppRoute.bvnVerification.name);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message, style: const TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF1D3108),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
                          'Join PayAjo',
                          style: TextStyle(fontFamily: 'SpaceGrotesk',
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1D3108),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start saving and growing together.',
                          style: TextStyle(fontFamily: 'PlusJakartaSans', 
                            fontSize: 15,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 36),

                        // First Name & Last Name Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildLabeledField(
                                label: 'First Name',
                                controller: _firstNameController,
                                hintText: 'Johan',
                                validator: (value) => _validateRequired(value, 'First name'),
                                textCapitalization: TextCapitalization.words,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildLabeledField(
                                label: 'Last Name',
                                controller: _lastNameController,
                                hintText: 'Mandela',
                                validator: (value) => _validateRequired(value, 'Last name'),
                                textCapitalization: TextCapitalization.words,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Username Field
                        _buildLabeledField(
                          label: 'Username',
                          controller: _usernameController,
                          hintText: 'johanmandela',
                          validator: _validateUsername,
                          textCapitalization: TextCapitalization.none,
                        ),
                        const SizedBox(height: 20),

                        // Email Field
                        _buildLabeledField(
                          label: 'Email',
                          controller: _emailController,
                          hintText: 'brittnilonda5487@gmail.com',
                          validator: _validateEmail,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 20),

                        // Phone Field
                        _buildLabeledField(
                          label: 'Phone',
                          controller: _phoneController,
                          hintText: '+2348012345678',
                          validator: _validatePhone,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 20),

                        // Password Field
                        Text(
                          'Password',
                          style: TextStyle(fontFamily: 'PlusJakartaSans', 
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1D3108),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          validator: _validatePassword,
                          style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF1D3108)),
                          decoration: InputDecoration(
                            hintText: 'password',
                            hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14, fontWeight: FontWeight.w400),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: Colors.grey[400],
                                size: 20,
                              ),
                            ),
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
                        const SizedBox(height: 16),

                        // Terms & Conditions Checkbox
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SGuideCheckbox(
                              value: _agreeToTerms,
                              onChanged: (val) {
                                setState(() {
                                  _agreeToTerms = val ?? false;
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'I agree to the Term & Condition and Privacy',
                                style: TextStyle(fontFamily: 'PlusJakartaSans', 
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Spacer to push button group to the bottom
                        const Spacer(),
                        const SizedBox(height: 24),


                        // Agreement Notice
                        Align(
                          alignment: Alignment.center,
                          child: Text(
                            'By entering and tapping Sign up, you agree to the\nTerms, E-Sign Consent & Privacy Notice',
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

                        // Action Buttons Row (CashApp Style)
                        Row(
                          children: [
                            // Sign In Button (Left, Pill shape, light background)
                            Expanded(
                              child: SizedBox(
                                height: 50,
                                child: TextButton(
                                  onPressed: () {
                                    context.goNamed(AppRoute.login.name);
                                  },
                                  style: TextButton.styleFrom(
                                    backgroundColor: const Color(0xFFF3F4F6),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(25),
                                    ),
                                  ),
                                  child: Text(
                                    'Sign in',
                                    style: TextStyle(fontFamily: 'SpaceGrotesk', 
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF4B5563),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Sign Up Button (Right, Pill shape, brand solid green)
                            Expanded(
                              child: SizedBox(
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: _isSubmitting ? null : _handleSignUp,
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
                                  child: _isSubmitting
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Color(0xFF1D3108),
                                          ),
                                        )
                                      : Text(
                                          'Sign up',
                                          style: TextStyle(fontFamily: 'SpaceGrotesk', 
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ],
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

  Widget _buildLabeledField({
    required String label,
    required TextEditingController controller,
    required String hintText,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontFamily: 'PlusJakartaSans', 
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1D3108),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          validator: validator,
          style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF1D3108)),
          decoration: InputDecoration(
            hintText: hintText,
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
      ],
    );
  }

}

// Custom widget to style Checkbox nicely
class SGuideCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;

  const SGuideCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: Checkbox(
        value: value,
        activeColor: const Color(0xFF5BA72D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
