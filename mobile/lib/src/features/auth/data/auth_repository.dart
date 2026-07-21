import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage_service.dart';

class RegisterRequest {
  final String email;
  final String username;
  final String firstName;
  final String lastName;
  final String password;
  final String phone;
  final String? fcmToken;

  const RegisterRequest({
    required this.email,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.password,
    required this.phone,
    this.fcmToken,
  });

  Map<String, dynamic> toJson() => {
        'email': email,
        'username': username,
        'first_name': firstName,
        'last_name': lastName,
        'password': password,
        'phone': phone,
        if (fcmToken != null && fcmToken!.isNotEmpty) 'fcm_token': fcmToken,
      };
}

class AuthRepository {
  final ApiClient _apiClient;
  final SecureStorageService _secureStorage;

  AuthRepository({
    required ApiClient apiClient,
    required SecureStorageService secureStorage,
  })  : _apiClient = apiClient,
        _secureStorage = secureStorage;

  /// Registers a new user and persists the returned access token to
  /// secure storage. Throws [ApiException] on failure.
  Future<void> register(RegisterRequest request) async {
    final response = await _apiClient.post(ApiConstants.register, body: request.toJson());
    await _saveToken(response);
  }

  /// Logs in an existing user and persists the returned access token to
  /// secure storage. Throws [ApiException] on failure.
  Future<void> login({required String email, required String password, String? fcmToken}) async {
    final response = await _apiClient.post(
      ApiConstants.login,
      body: {
        'email': email,
        'password': password,
        if (fcmToken != null && fcmToken.isNotEmpty) 'fcm_token': fcmToken,
      },
    );
    await _saveToken(response);
  }

  /// Sets the user's transaction PIN. Backend enforces this can only be
  /// called once per account — a repeat call throws [ApiException].
  Future<void> setupPin(String pin) async {
    await _apiClient.post(
      ApiConstants.setupPin,
      body: {'pin': pin},
      headers: await _secureStorage.authHeaders(),
    );
  }

  /// Sends a PIN-reset OTP to the user's registered email.
  Future<void> requestPinReset() async {
    await _apiClient.post(ApiConstants.requestPinReset, headers: await _secureStorage.authHeaders());
  }

  /// Resets the PIN using the OTP emailed to the user.
  Future<void> resetPin({required String otpCode, required String newPin}) async {
    await _apiClient.post(
      ApiConstants.resetPin,
      body: {'otp_code': otpCode, 'new_pin': newPin},
      headers: await _secureStorage.authHeaders(),
    );
  }

  /// Sends a password-reset OTP to the given email. Unlike PIN reset, this
  /// is called by a signed-out user, so it carries no auth headers.
  Future<void> requestPasswordReset({required String email}) async {
    await _apiClient.post(ApiConstants.forgotPassword, body: {'email': email});
  }

  /// Resets the account password using the OTP emailed to the user.
  Future<void> resetPasswordWithOtp({
    required String email,
    required String otpCode,
    required String newPassword,
  }) async {
    await _apiClient.post(
      ApiConstants.resetPassword,
      body: {'email': email, 'otp_code': otpCode, 'new_password': newPassword},
    );
  }

  Future<void> _saveToken(Map<String, dynamic> response) async {
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw ApiException('Unexpected response from server.');
    }

    final accessToken = data['access_token'];
    if (accessToken is! String || accessToken.isEmpty) {
      throw ApiException('Unexpected response from server.');
    }

    final tokenType = data['token_type'] as String?;
    await _secureStorage.saveAccessToken(accessToken, tokenType: tokenType);
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    apiClient: ref.watch(apiClientProvider),
    secureStorage: ref.watch(secureStorageServiceProvider),
  );
});
