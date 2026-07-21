import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../core/utils/polling.dart';
import 'user_profile.dart';

/// Caches the last-fetched profile so other screens (Home, PIN setup)
/// can read `has_pin`, `kyc_status`, wallet balance, etc. without refetching.
final currentUserProvider = StateProvider<UserProfile?>((ref) => null);

/// Set by [ApiClient.onUnauthorized] right before it bounces to login, so
/// the login screen can show "your session expired" instead of a bare form.
/// The login screen resets this back to false once it's shown the banner.
final sessionExpiredProvider = StateProvider<bool>((ref) => false);

/// From `GET /users/search` — an exact-match lookup by email or username,
/// used to preview who an admin is about to invite before sending it.
class UserSearchResult {
  final String id;
  final String username;
  final String firstName;
  final String lastName;
  final int riskScore;
  final String? riskFactors;

  const UserSearchResult({
    required this.id,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.riskScore,
    this.riskFactors,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory UserSearchResult.fromJson(Map<String, dynamic> json) {
    return UserSearchResult(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      riskScore: (json['risk_score'] as num?)?.toInt() ?? 0,
      riskFactors: json['risk_factors']?.toString(),
    );
  }
}

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

  /// Updates basic profile fields. Only non-null args are sent, so leaving
  /// one out preserves whatever the backend already has for it.
  Future<UserProfile> updateProfile({String? firstName, String? lastName, String? phone}) async {
    final response = await _apiClient.patch(
      ApiConstants.me,
      body: {
        if (firstName != null) 'first_name': firstName,
        if (lastName != null) 'last_name': lastName,
        if (phone != null) 'phone': phone,
      },
      headers: await _secureStorage.authHeaders(),
    );
    return _parseUser(response);
  }

  /// Uploads a new profile picture. Throws [ApiException] on failure.
  Future<UserProfile> uploadAvatar({required List<int> bytes, required String filename, String? contentType}) async {
    final response = await _apiClient.postMultipart(
      ApiConstants.avatar,
      fileBytes: bytes,
      filename: filename,
      contentType: contentType,
      headers: await _secureStorage.authHeaders(),
    );
    return _parseUser(response);
  }

  /// Looks up a user by exact email or username. Returns `null` if no user
  /// matches (the backend 404s / errors for a non-match rather than
  /// returning an empty result).
  Future<UserSearchResult?> searchUser(String query) async {
    try {
      final response = await _apiClient.get(
        ApiConstants.searchUser(query),
        headers: await _secureStorage.authHeaders(),
      );
      final data = response['data'];
      if (data is! Map<String, dynamic>) return null;
      return UserSearchResult.fromJson(data);
    } on ApiException {
      return null;
    }
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
  bool _hasSyncedFcmToken = false;

  @override
  UserProfileState build() {
    Future.microtask(refresh);
    // Wallet balance is the thing users most want to see update without a
    // manual pull-to-refresh (e.g. right after a bank transfer lands).
    startPolling(ref, const Duration(seconds: 20), refresh);
    return const UserProfileState(isLoading: true);
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final profile = await ref.read(userRepositoryProvider).getMe();
      ref.read(currentUserProvider.notifier).state = profile;
      state = UserProfileState(profile: profile, isLoading: false);
      // Only needs to happen once per session, not on every poll tick.
      if (!_hasSyncedFcmToken) {
        _hasSyncedFcmToken = true;
        NotificationService().syncTokenWithBackend(null);
      }
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    }
  }
}

final userProfileControllerProvider = NotifierProvider<UserProfileController, UserProfileState>(
  UserProfileController.new,
);
