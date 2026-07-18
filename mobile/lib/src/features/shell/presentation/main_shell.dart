import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../home/presentation/home_tab.dart';
import '../../wallet/presentation/wallet_tab.dart';
import '../../notifications/presentation/notifications_tab.dart';
import '../../notifications/data/notifications_repository.dart';
import '../../profile/presentation/profile_tab.dart';
import '../data/shell_tab_provider.dart';
import 'widgets/app_bottom_nav.dart';

/// Root of the authenticated app: a persistent bottom-nav shell with 4
/// tabs. Uses IndexedStack so each tab keeps its scroll position and
/// in-flight state when switching away and back.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;

  static const _tabs = [
    HomeTab(),
    WalletTab(),
    NotificationsTab(),
    ProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 220), value: 1);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _onTap(int index) {
    if (index == ref.read(selectedTabIndexProvider)) return;
    ref.read(selectedTabIndexProvider.notifier).state = index;
    _fadeController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = ref.watch(hasUnreadNotificationsProvider);
    final index = ref.watch(selectedTabIndexProvider);

    // A screen pushed on top of the shell (e.g. Contribution) can jump the
    // user to a specific tab by setting selectedTabIndexProvider and then
    // navigating back to `home` — this plays the same fade transition.
    ref.listen<int>(selectedTabIndexProvider, (previous, next) {
      if (previous != next) _fadeController.forward(from: 0);
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      // FadeTransition wraps the same IndexedStack instance across rebuilds
      // (not keyed/replaced), so tab state survives switches — only opacity animates.
      body: FadeTransition(
        opacity: _fadeController,
        child: IndexedStack(index: index, children: _tabs),
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: index,
        showNotificationDot: hasUnread,
        onTap: _onTap,
      ),
    );
  }
}
