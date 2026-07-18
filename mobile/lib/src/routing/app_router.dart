import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/splash/presentation/splash_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/presentation/bvn_verification_screen.dart';
import '../features/auth/presentation/join_or_create_screen.dart';
import '../features/auth/presentation/create_group_success_screen.dart';
import '../features/auth/presentation/join_group_success_screen.dart';
import '../features/auth/presentation/create_pin_screen.dart';
import '../features/auth/presentation/confirm_pin_screen.dart';
import '../features/auth/presentation/reset_pin/request_pin_reset_screen.dart';
import '../features/auth/presentation/reset_pin/otp_verification_screen.dart';
import '../features/auth/presentation/reset_pin/reset_new_pin_screen.dart';
import '../features/auth/presentation/reset_pin/reset_confirm_pin_screen.dart';
import '../features/auth/presentation/reset_pin/pin_reset_success_screen.dart';
import '../features/groups/presentation/group_details_screen.dart';
import '../features/groups/presentation/group_chat_screen.dart';
import '../features/groups/presentation/contribution_screen.dart';
import '../features/groups/presentation/my_groups_screen.dart';
import '../features/groups/presentation/my_invites_screen.dart';
import '../features/shell/presentation/main_shell.dart';

enum AppRoute {
  splash,
  onboarding,
  login,
  register,
  bvnVerification,
  joinOrCreate,
  createGroupSuccess,
  joinGroupSuccess,
  pinSetup,
  confirmPin,
  requestPinReset,
  verifyPinResetOtp,
  resetNewPin,
  resetConfirmPin,
  pinResetSuccess,
  groupDetails,
  groupChat,
  contribution,
  myGroups,
  myInvites,
  home,
}

/// Fade transition helper — used across secondary screens for a calm,
/// consistent page transition (per the "smooth, 250-500ms" brief).
CustomTransitionPage<void> _fadePage(GoRouterState state, Widget child, {Duration duration = const Duration(milliseconds: 300)}) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: duration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut), child: child);
    },
  );
}

final goRouter = GoRouter(
  initialLocation: '/',
  debugLogDiagnostics: true,
  routes: [
    GoRoute(
      path: '/',
      name: AppRoute.splash.name,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      name: AppRoute.onboarding.name,
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/login',
      name: AppRoute.login.name,
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      name: AppRoute.register.name,
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/bvn-verification',
      name: AppRoute.bvnVerification.name,
      builder: (context, state) => const BvnVerificationScreen(),
    ),
    GoRoute(
      path: '/join-or-create',
      name: AppRoute.joinOrCreate.name,
      builder: (context, state) => const JoinOrCreateScreen(),
    ),
    GoRoute(
      path: '/create-group-success',
      name: AppRoute.createGroupSuccess.name,
      builder: (context, state) => CreateGroupSuccessScreen(
        data: state.extra as CreateGroupSuccessData,
      ),
    ),
    GoRoute(
      path: '/join-group-success',
      name: AppRoute.joinGroupSuccess.name,
      builder: (context, state) => JoinGroupSuccessScreen(
        data: state.extra as JoinGroupSuccessData,
      ),
    ),
    GoRoute(
      path: '/pin-setup',
      name: AppRoute.pinSetup.name,
      pageBuilder: (context, state) => _fadePage(state, const CreatePinScreen(), duration: const Duration(milliseconds: 350)),
    ),
    GoRoute(
      path: '/pin-confirm',
      name: AppRoute.confirmPin.name,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: ConfirmPinScreen(pin: state.extra as String),
        transitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
            child: child,
          );
        },
      ),
    ),
    GoRoute(
      path: '/pin-reset/request',
      name: AppRoute.requestPinReset.name,
      builder: (context, state) => const RequestPinResetScreen(),
    ),
    GoRoute(
      path: '/pin-reset/verify-otp',
      name: AppRoute.verifyPinResetOtp.name,
      builder: (context, state) => const OtpVerificationScreen(),
    ),
    GoRoute(
      path: '/pin-reset/new-pin',
      name: AppRoute.resetNewPin.name,
      pageBuilder: (context, state) => _fadePage(state, ResetNewPinScreen(otpCode: state.extra as String)),
    ),
    GoRoute(
      path: '/pin-reset/confirm-pin',
      name: AppRoute.resetConfirmPin.name,
      pageBuilder: (context, state) {
        final args = state.extra as Map<String, String>;
        return CustomTransitionPage(
          key: state.pageKey,
          child: ResetConfirmPinScreen(otpCode: args['otp']!, pin: args['pin']!),
          transitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: '/pin-reset/success',
      name: AppRoute.pinResetSuccess.name,
      pageBuilder: (context, state) => _fadePage(state, const PinResetSuccessScreen()),
    ),
    GoRoute(
      path: '/group-details',
      name: AppRoute.groupDetails.name,
      builder: (context, state) => GroupDetailsScreen(groupId: state.extra as String),
    ),
    GoRoute(
      path: '/group-chat',
      name: AppRoute.groupChat.name,
      builder: (context, state) => GroupChatScreen(groupId: state.extra as String),
    ),
    GoRoute(
      path: '/group-contribute',
      name: AppRoute.contribution.name,
      builder: (context, state) => ContributionScreen(groupId: state.extra as String),
    ),
    GoRoute(
      path: '/my-groups',
      name: AppRoute.myGroups.name,
      builder: (context, state) => const MyGroupsScreen(),
    ),
    GoRoute(
      path: '/my-invites',
      name: AppRoute.myInvites.name,
      builder: (context, state) => const MyInvitesScreen(),
    ),
    GoRoute(
      path: '/home',
      name: AppRoute.home.name,
      builder: (context, state) => const MainShell(),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Text(
        'Page not found: ${state.error}',
        style: const TextStyle(color: Colors.red),
      ),
    ),
  ),
);
