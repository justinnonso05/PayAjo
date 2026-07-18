import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import 'wallet_models.dart';
import 'wallet_repository.dart';

class WalletTransactionsState {
  final List<WalletTransaction> items;
  final bool isLoading;
  final String? error;

  const WalletTransactionsState({this.items = const [], this.isLoading = false, this.error});

  WalletTransactionsState copyWith({List<WalletTransaction>? items, bool? isLoading, String? error}) {
    return WalletTransactionsState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class WalletTransactionsController extends Notifier<WalletTransactionsState> {
  @override
  WalletTransactionsState build() {
    Future.microtask(refresh);
    return const WalletTransactionsState(isLoading: true);
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final items = await ref.read(walletRepositoryProvider).getTransactions();
      state = WalletTransactionsState(items: items, isLoading: false);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    }
  }
}

final walletTransactionsControllerProvider =
    NotifierProvider<WalletTransactionsController, WalletTransactionsState>(WalletTransactionsController.new);
