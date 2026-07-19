import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../auth/data/user_profile.dart';
import 'payout_bank_models.dart';
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

  /// Fetches a single transaction rendered as a receipt (amounts, names,
  /// dates, references) — used for the transaction detail view.
  Future<TransactionReceipt> getTransactionReceipt(String transactionId) async {
    final response = await _apiClient.get(
      ApiConstants.walletTransactionReceipt(transactionId),
      headers: await _secureStorage.authHeaders(),
    );
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw ApiException('Unexpected response from server.');
    }
    return TransactionReceipt.fromJson(data);
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

  /// Polls whether a Monnify payment has cleared. Returns `true` once the
  /// webhook has landed and the transaction is `successful`, `false` while
  /// still `pending`. Callers typically poll this on an interval after
  /// initiating a wallet top-up or direct group payment.
  Future<bool> isTransactionSuccessful(String paymentReference) async {
    final response = await _apiClient.get(
      ApiConstants.transactionStatus(paymentReference),
      headers: await _secureStorage.authHeaders(),
    );
    final data = response['data'];
    if (data is Map<String, dynamic>) {
      return data['status']?.toString() == 'successful';
    }
    return false;
  }

  /// Looks up who owns a reserved account number, so the sender can confirm
  /// the recipient's identity before transferring money to them.
  Future<UserByAccount> lookupByAccount(String accountNumber) async {
    final response = await _apiClient.get(
      ApiConstants.walletLookup(accountNumber),
      headers: await _secureStorage.authHeaders(),
    );
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw ApiException('Unexpected response from server.');
    }
    return UserByAccount.fromJson(data);
  }

  /// Sends [amount] from the caller's wallet to the wallet behind
  /// [recipientAccountNumber]. Throws [ApiException] on a wrong PIN,
  /// insufficient balance, or an unknown account number.
  Future<WalletTransaction> transfer({
    required String recipientAccountNumber,
    required double amount,
    required String pin,
    String? narration,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.walletTransfer,
      body: {
        'recipient_account_number': recipientAccountNumber,
        'amount': amount,
        'pin': pin,
        if (narration != null && narration.isNotEmpty) 'narration': narration,
      },
      headers: await _secureStorage.authHeaders(),
    );
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw ApiException('Unexpected response from server.');
    }
    return WalletTransaction.fromJson(data);
  }

  // --- Payout bank setup ---

  Future<List<Bank>> getBanks() async {
    final response = await _apiClient.get(ApiConstants.banks, headers: await _secureStorage.authHeaders());
    final data = response['data'];
    if (data is! List) return [];
    final banks = data.whereType<Map<String, dynamic>>().map(Bank.fromJson).toList();
    banks.sort((a, b) => a.name.compareTo(b.name));
    return banks;
  }

  /// "Name enquiry" — resolves the account holder's name so the user can
  /// confirm it's really their account before saving it.
  Future<BankValidationResult> validateBankAccount({required String accountNumber, required String bankCode}) async {
    final response = await _apiClient.get(
      ApiConstants.validateBankAccount(accountNumber, bankCode),
      headers: await _secureStorage.authHeaders(),
    );
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw ApiException('Unexpected response from server.');
    }
    return BankValidationResult.fromJson(data);
  }

  /// Sends an OTP (to the user's registered email) required before
  /// changing the payout bank.
  Future<void> requestPayoutBankOtp() async {
    await _apiClient.post(ApiConstants.requestPayoutBankOtp, headers: await _secureStorage.authHeaders());
  }

  /// Sets the payout bank. Throws [ApiException] on a bad/expired OTP.
  Future<UserProfile> setPayoutBank({
    required String bankAccountNumber,
    required String bankCode,
    required String otpCode,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.setPayoutBank,
      body: {
        'bank_account_number': bankAccountNumber,
        'bank_code': bankCode,
        'otp_code': otpCode,
      },
      headers: await _secureStorage.authHeaders(),
    );
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw ApiException('Unexpected response from server.');
    }
    return UserProfile.fromJson(data);
  }
}

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepository(
    apiClient: ref.watch(apiClientProvider),
    secureStorage: ref.watch(secureStorageServiceProvider),
  );
});
