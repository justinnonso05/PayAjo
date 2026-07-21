import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Starts a periodic background refresh for a [Notifier]'s `build()`, so
/// screens stay up to date (payment status, balances, unread notifications)
/// without the user having to manually pull-to-refresh. Skips ticks while
/// the app isn't in the foreground, and cancels itself when the provider
/// is disposed.
void startPolling(Ref ref, Duration interval, Future<void> Function() action) {
  final timer = Timer.periodic(interval, (_) {
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      action();
    }
  });
  ref.onDispose(timer.cancel);
}
