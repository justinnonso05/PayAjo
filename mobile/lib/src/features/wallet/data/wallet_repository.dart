import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage_service.dart';
import 'wallet_models.dart';

class WalletRepository {
  final ApiClient _apiClient;
  final SecureStorageService _secureStorage;

  WalletRepository({
    required ApiClient apiClient,
    required SecureStorageService secureStorage,
  })  : _apiClient = apiClient,
        _secureStorage = secureStorage;

  Future<List<WalletTransaction>> getTransactions() async {
    final response = await _apiClient.get(
      ApiConstants.walletTransactions,
      headers: await _secureStorage.authHeaders(),
    );
    final data = response['data'];
    if (data is! List) return [];
    final items = data.whereType<Map<String, dynamic>>().map(WalletTransaction.fromJson).toList();
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  /// Withdraws [amount] from the wallet to the user's payout bank.
  /// Throws [ApiException] on failure (insufficient balance, wrong PIN,
  /// no payout bank on file, etc).
  Future<WalletTransaction> withdraw({required double amount, required String pin}) async {
    final response = await _apiClient.post(
      ApiConstants.walletWithdraw,
      body: {'amount': amount, 'pin': pin},
      headers: await _secureStorage.authHeaders(),
    );
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw ApiException('Unexpected response from server.');
    }
    return WalletTransaction.fromJson(data);
  }
}

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepository(
    apiClient: ref.watch(apiClientProvider),
    secureStorage: ref.watch(secureStorageServiceProvider),
  );
});
