import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage_service.dart';
import 'user_profile.dart';

/// Caches the last-fetched profile so other screens (Home, PIN setup)
/// can read `has_pin`, `kyc_status`, wallet balance, etc. without refetching.
final currentUserProvider = StateProvider<UserProfile?>((ref) => null);

class UserRepository {
  final ApiClient _apiClient;
  final SecureStorageService _secureStorage;

  UserRepository({
    required ApiClient apiClient,
    required SecureStorageService secureStorage,
  })  : _apiClient = apiClient,
        _secureStorage = secureStorage;

  /// Submits the user's BVN for mock identity verification.
  Future<UserProfile> mockVerifyKyc(String bvn) async {
    final response = await _apiClient.post(
      ApiConstants.mockKycVerify,
      body: {'bvn': bvn},
      headers: await _secureStorage.authHeaders(),
    );
    return _parseUser(response);
  }

  Future<UserProfile> getMe() async {
    final response = await _apiClient.get(
      ApiConstants.me,
      headers: await _secureStorage.authHeaders(),
    );
    return _parseUser(response);
  }

  UserProfile _parseUser(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw ApiException('Unexpected response from server.');
    }
    return UserProfile.fromJson(data);
  }
}

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(
    apiClient: ref.watch(apiClientProvider),
    secureStorage: ref.watch(secureStorageServiceProvider),
  );
});

class UserProfileState {
  final UserProfile? profile;
  final bool isLoading;
  final String? error;

  const UserProfileState({this.profile, this.isLoading = false, this.error});

  UserProfileState copyWith({UserProfile? profile, bool? isLoading, String? error}) {
    return UserProfileState(
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Shared, fetch-once-per-session source of truth for the current user's
/// profile (wallet balance, reserved account, KYC/PIN flags). Home, Wallet
/// and Profile tabs all watch this instead of each calling /users/me.
class UserProfileController extends Notifier<UserProfileState> {
  @override
  UserProfileState build() {
    Future.microtask(refresh);
    return const UserProfileState(isLoading: true);
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final profile = await ref.read(userRepositoryProvider).getMe();
      ref.read(currentUserProvider.notifier).state = profile;
      state = UserProfileState(profile: profile, isLoading: false);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    }
  }
}

final userProfileControllerProvider = NotifierProvider<UserProfileController, UserProfileState>(
  UserProfileController.new,
);
