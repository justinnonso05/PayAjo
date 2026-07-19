import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../routing/app_router.dart';
import '../../auth/data/user_repository.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Icon Animations (markIn: 16% to 39%)
  late final Animation<double> _iconScale;
  late final Animation<double> _iconOpacity;

  // Word Animations (wordIn: 67% to 80%)
  late final Animation<double> _wordOpacity;
  late final Animation<double> _wordTranslate;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    // Icon Scale & Opacity: Starts from 16% (0.16) and finishes by 39% (0.39)
    _iconScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.16, 0.39, curve: Curves.easeOut),
      ),
    );
    _iconOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.16, 0.39, curve: Curves.easeOut),
      ),
    );

    // Word Opacity & TranslateX: Starts from 67% (0.67) and finishes by 80% (0.80)
    _wordOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.67, 0.80, curve: Curves.easeOut),
      ),
    );
    _wordTranslate = Tween<double>(begin: -6.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.67, 0.80, curve: Curves.easeOut),
      ),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _resolveDestination());
        }
      }
    });

    _controller.forward();
  }

  /// Once signed in, the app should reopen straight to Home (or wherever
  /// the account's setup is unfinished) instead of onboarding every time —
  /// so this checks for a stored session and validates it against the
  /// backend before deciding where to land.
  Future<void> _resolveDestination() async {
    final token = await ref.read(secureStorageServiceProvider).readAccessToken();
    if (token == null || token.isEmpty) {
      if (mounted) context.goNamed(AppRoute.onboarding.name);
      return;
    }

    try {
      final profile = await ref.read(userRepositoryProvider).getMe();
      ref.read(currentUserProvider.notifier).state = profile;
      if (!mounted) return;

      if (!profile.kycStatus) {
        context.goNamed(AppRoute.bvnVerification.name);
      } else if (!profile.hasPin) {
        context.goNamed(AppRoute.pinSetup.name);
      } else {
        context.goNamed(AppRoute.home.name);
      }
    } on ApiException {
      // Token expired/invalid — clear it and fall back to onboarding.
      await ref.read(secureStorageServiceProvider).clear();
      if (mounted) context.goNamed(AppRoute.onboarding.name);
    } catch (_) {
      await ref.read(secureStorageServiceProvider).clear();
      if (mounted) context.goNamed(AppRoute.onboarding.name);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void reassemble() {
    super.reassemble();
    if (mounted) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFACEC87), // light green brand color matching screenshot
      body: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Animated Icon / Mark
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Opacity(
                  opacity: _iconOpacity.value,
                  child: Transform.scale(
                    scale: _iconScale.value,
                    child: child,
                  ),
                );
              },
              child: CustomPaint(
                size: const Size(56, 56),
                painter: LogoMarkPainter(),
              ),
            ),
            const SizedBox(width: 12),
            // Animated Word / Text
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Opacity(
                  opacity: _wordOpacity.value,
                  child: Transform.translate(
                    offset: Offset(_wordTranslate.value, 0),
                    child: child,
                  ),
                );
              },
              child: Text(
                'AjoPay',
                style: TextStyle(fontFamily: 'SpaceGrotesk', 
                  fontSize: 38,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1D3108),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LogoMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1D3108)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 34
      ..strokeCap = StrokeCap.round;

    // Scale canvas coordinates to match original viewBox 340 x 340
    final double scaleX = size.width / 340.0;
    final double scaleY = size.height / 340.0;

    canvas.save();
    canvas.scale(scaleX, scaleY);

    // Path 1: M238.9,112.1 A90,90 0 0,1 101.1,112.1
    final path1 = Path()
      ..moveTo(238.9, 112.1)
      ..arcToPoint(
        const Offset(101.1, 112.1),
        radius: const Radius.circular(90),
        clockwise: true,
      );
    canvas.drawPath(path1, paint);

    // Path 2: M185.6,258.6 A90,90 0 0,1 254.6,139.2
    final path2 = Path()
      ..moveTo(185.6, 258.6)
      ..arcToPoint(
        const Offset(254.6, 139.2),
        radius: const Radius.circular(90),
        clockwise: true,
      );
    canvas.drawPath(path2, paint);

    // Path 3: M85.4,139.2 A90,90 0 0,1 154.4,258.6
    final path3 = Path()
      ..moveTo(85.4, 139.2)
      ..arcToPoint(
        const Offset(154.4, 258.6),
        radius: const Radius.circular(90),
        clockwise: true,
      );
    canvas.drawPath(path3, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}