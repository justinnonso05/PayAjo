import 'package:flutter_riverpod/legacy.dart';

/// Which bottom-nav tab is selected. Screens pushed on top of [MainShell]
/// (e.g. Contribution wanting to send the user to the Wallet tab) set this
/// and then navigate back to the `home` route rather than trying to push
/// a nonexistent "/wallet" route.
final selectedTabIndexProvider = StateProvider<int>((ref) => 0);
