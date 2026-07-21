import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../routing/app_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../groups/data/group_invites_controller.dart';
import '../../home/data/home_controller.dart';
import '../../notifications/data/notifications_repository.dart';
import '../../wallet/data/wallet_controller.dart';
import '../data/auth_repository.dart';
import '../data/user_repository.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _obscurePassword = true;
  bool _isSubmitting = false;

  static final RegExp _emailRegExp = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void initState() {
    super.initState();
    _prefillLastEmail();
    // Show the "session expired" banner once, then clear the flag so it
    // doesn't reappear on a later, unrelated visit to this screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(sessionExpiredProvider)) {
        ref.read(sessionExpiredProvider.notifier).state = false;
      }
    });
  }

  Future<void> _prefillLastEmail() async {
    final email = await ref.read(secureStorageServiceProvider).readLastEmail();
    if (email == null || !mounted) return;
    setState(() {
      _emailController.text = email;
      _rememberMe = true;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Email is required';
    if (!_emailRegExp.hasMatch(trimmed)) return 'Enter a valid email address';
    return null;
  }

  String? _validatePassword(String? value) {
    if ((value ?? '').isEmpty) return 'Password is required';
    return null;
  }

  Future<void> _handleLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ref.read(authRepositoryProvider).login(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            fcmToken: NotificationService().currentToken,
          );

      final profile = await ref.read(userRepositoryProvider).getMe();
      ref.read(currentUserProvider.notifier).state = profile;
      await ref.read(secureStorageServiceProvider).saveLastEmail(_emailController.text.trim());
      // A previous session's 401 may have latched the "already handling
      // an expired session" guard — a fresh successful login clears it.
      ApiClient.resetUnauthorizedGuard();

      // These are all NotifierProviders that fetch once on first read and
      // then cache — if any of them were already built earlier in this app
      // session (e.g. a previous account's session before logout), they'd
      // otherwise keep showing that stale data until the user manually
      // pulls to refresh. Invalidating forces a fresh fetch for this account.
      ref.invalidate(homeControllerProvider);
      ref.invalidate(walletTransactionsControllerProvider);
      ref.invalidate(notificationsControllerProvider);
      ref.invalidate(groupInvitesControllerProvider);

      if (!mounted) return;

      if (!profile.kycStatus) {
        context.goNamed(AppRoute.bvnVerification.name);
      } else if (!profile.hasPin) {
        context.goNamed(AppRoute.pinSetup.name);
      } else {
        context.goNamed(AppRoute.home.name);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message, style: TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF1D3108)),
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
                          'Welcome to PayAjo',
                          style: TextStyle(fontFamily: 'SpaceGrotesk',
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1D3108),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Save together. Grow together.',
                          style: TextStyle(fontFamily: 'PlusJakartaSans', 
                            fontSize: 15,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 36),
                        if (ref.watch(sessionExpiredProvider))
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3E0),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFB45309)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Your session expired. Please log in again.',
                                    style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFFB45309)),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Email Field
                        Text(
                          'Email',
                          style: TextStyle(fontFamily: 'PlusJakartaSans', 
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1D3108),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          validator: _validateEmail,
                          style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF1D3108)),
                          decoration: InputDecoration(
                            hintText: 'brittnilonda5487@gmail.com',
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
                            hintText: '••••••••',
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

                        // Remember Me & Forgot Password
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Checkbox(
                                    value: _rememberMe,
                                    activeColor: const Color(0xFF5BA72D),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    onChanged: (val) {
                                      setState(() {
                                        _rememberMe = val ?? false;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Remember me',
                                  style: TextStyle(fontFamily: 'PlusJakartaSans', 
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            GestureDetector(
                              onTap: () => context.pushNamed(AppRoute.requestPasswordReset.name),
                              child: Text(
                                'Forgot Password?',
                                style: TextStyle(fontFamily: 'PlusJakartaSans', 
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF5BA72D),
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
                            'By entering and tapping Log in, you agree to the\nTerms, E-Sign Consent & Privacy Notice',
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
                            // Sign Up Button (Left, Pill shape, light background)
                            Expanded(
                              child: SizedBox(
                                height: 50,
                                child: TextButton(
                                  onPressed: () {
                                    context.goNamed(AppRoute.register.name);
                                  },
                                  style: TextButton.styleFrom(
                                    backgroundColor: const Color(0xFFF3F4F6),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(25),
                                    ),
                                  ),
                                  child: Text(
                                    'Sign up',
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
                            // Log In Button (Right, Pill shape, brand solid green)
                            Expanded(
                              child: SizedBox(
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: _isSubmitting ? null : _handleLogin,
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
                                          'Log in',
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

}
