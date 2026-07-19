import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage_service.dart';
import 'group_models.dart';

class GroupRepository {
  final ApiClient _apiClient;
  final SecureStorageService _secureStorage;

  GroupRepository({
    required ApiClient apiClient,
    required SecureStorageService secureStorage,
  })  : _apiClient = apiClient,
        _secureStorage = secureStorage;

  Future<GroupResponse> createGroup(GroupCreateRequest request) async {
    final response = await _apiClient.post(
      ApiConstants.groups,
      body: request.toJson(),
      headers: await _secureStorage.authHeaders(),
    );
    return _parseGroup(response);
  }

  Future<GroupResponse> joinGroup(String inviteCode) async {
    final response = await _apiClient.post(
      ApiConstants.joinGroup,
      body: {'invite_code': inviteCode},
      headers: await _secureStorage.authHeaders(),
    );
    return _parseGroup(response);
  }

  /// Returns how many members are in [groupId]. Used to populate the
  /// Join Group success screen, since the join response itself doesn't
  /// include a member count.
  Future<int> getMemberCount(String groupId) async {
    final members = await getMembers(groupId);
    return members.length;
  }

  Future<List<GroupMember>> getMembers(String groupId) async {
    final response = await _apiClient.get(
      ApiConstants.groupMembers(groupId),
      headers: await _secureStorage.authHeaders(),
    );
    final data = response['data'];
    if (data is! List) return [];
    return data.whereType<Map<String, dynamic>>().map(GroupMember.fromJson).toList();
  }

  /// Full ordered payout schedule for the group — who gets paid each
  /// cycle, whether it's completed, and the current cycle's payout date.
  Future<List<GroupRotationEntry>> getRotations(String groupId) async {
    final response = await _apiClient.get(
      ApiConstants.groupRotations(groupId),
      headers: await _secureStorage.authHeaders(),
    );
    final data = response['data'];
    if (data is! List) return [];
    return data.whereType<Map<String, dynamic>>().map(GroupRotationEntry.fromJson).toList();
  }

  Future<List<UserGroupMembership>> getMyGroups() async {
    final response = await _apiClient.get(
      ApiConstants.myGroups,
      headers: await _secureStorage.authHeaders(),
    );
    final data = response['data'];
    if (data is! List) return [];
    return data.whereType<Map<String, dynamic>>().map(UserGroupMembership.fromJson).toList();
  }

  Future<GroupResponse> getGroup(String groupId) async {
    final response = await _apiClient.get(
      ApiConstants.group(groupId),
      headers: await _secureStorage.authHeaders(),
    );
    return _parseGroup(response);
  }

  /// Pays the current contribution from the user's wallet balance.
  /// Throws [ApiException] (e.g. insufficient balance, wrong PIN).
  Future<GroupResponse> payFromWallet(String groupId, String pin) async {
    final response = await _apiClient.post(
      ApiConstants.payFromWallet(groupId),
      body: {'pin': pin},
      headers: await _secureStorage.authHeaders(),
    );
    return _parseGroup(response);
  }

  /// Generates a one-time virtual account + checkout link for paying the
  /// current contribution directly (bank transfer / card), as an
  /// alternative to paying from the in-app wallet balance. Expires after
  /// `accountDurationSeconds` (currently 40 minutes).
  Future<DirectPaymentDetails> generateDirectPayment(String groupId) async {
    final response = await _apiClient.post(
      ApiConstants.generateDirectPayment(groupId),
      headers: await _secureStorage.authHeaders(),
    );
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw ApiException('Unexpected response from server.');
    }
    return DirectPaymentDetails.fromJson(data);
  }

  // --- Admin actions ---

  Future<List<PendingMembership>> getPendingMembers(String groupId) async {
    final response = await _apiClient.get(
      ApiConstants.pendingMembers(groupId),
      headers: await _secureStorage.authHeaders(),
    );
    final data = response['data'];
    if (data is! List) return [];
    return data.whereType<Map<String, dynamic>>().map(PendingMembership.fromJson).toList();
  }

  Future<void> approveMember(String groupId, String userId) async {
    await _apiClient.post(
      ApiConstants.approveMember(groupId, userId),
      headers: await _secureStorage.authHeaders(),
    );
  }

  Future<GroupResponse> updateGroup(String groupId, GroupUpdateRequest request) async {
    final response = await _apiClient.patch(
      ApiConstants.group(groupId),
      body: request.toJson(),
      headers: await _secureStorage.authHeaders(),
    );
    return _parseGroup(response);
  }

  /// Starts the group's contribution cycle, fixing the payout rotation order.
  Future<GroupResponse> startGroup(String groupId, {bool randomize = true, List<String>? manualOrder}) async {
    final response = await _apiClient.post(
      ApiConstants.startGroup(groupId),
      body: {
        'randomize': randomize,
        if (manualOrder != null) 'manual_order': manualOrder,
      },
      headers: await _secureStorage.authHeaders(),
    );
    return _parseGroup(response);
  }

  /// Regenerates the group's invite code, invalidating the old one.
  Future<GroupResponse> rotateInviteCode(String groupId) async {
    final response = await _apiClient.post(
      ApiConstants.rotateInviteCode(groupId),
      headers: await _secureStorage.authHeaders(),
    );
    return _parseGroup(response);
  }

  /// Sends an AI-crafted payment reminder to one member (email, chat, and
  /// notification). Admin-only; doesn't require knowing the member's paid
  /// status client-side — the backend decides what to say.
  Future<void> sendMemberReminder(String groupId, String userId) async {
    await _apiClient.post(
      ApiConstants.sendMemberReminder(groupId, userId),
      headers: await _secureStorage.authHeaders(),
    );
  }

  /// Reminds every member of the group who hasn't yet paid for the current
  /// cycle. Admin-only.
  Future<void> sendRemindersBulk(String groupId) async {
    await _apiClient.post(
      ApiConstants.sendRemindersBulk(groupId),
      headers: await _secureStorage.authHeaders(),
    );
  }

  /// Manually runs the payout scheduler across every group (not just this
  /// one) — for testing/demo, so a due payout doesn't have to wait for the
  /// real cron interval. Returns the backend's status message.
  Future<String> triggerScheduler() async {
    final response = await _apiClient.post(
      ApiConstants.triggerScheduler,
      headers: await _secureStorage.authHeaders(),
    );
    return response['data']?.toString() ?? 'Payout scheduler triggered.';
  }

  /// Enables/disables auto-debit for the current user's own membership in
  /// this group — when enabled, the backend automatically pays the
  /// contribution from wallet balance once within [daysBefore] days of the
  /// next payout date, as long as it hasn't been paid yet. PIN-confirmed
  /// since it authorizes a standing outbound money instruction.
  Future<GroupMember> setupAutoDebit(
    String groupId, {
    required bool enabled,
    required int daysBefore,
    required String pin,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.autoDebit(groupId),
      body: {
        'enabled': enabled,
        'days_before': daysBefore,
        'pin': pin,
      },
      headers: await _secureStorage.authHeaders(),
    );
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw ApiException('Unexpected response from server.');
    }
    return GroupMember.fromJson(data);
  }

  // --- Invites (direct, by email/username — separate from invite codes) ---

  Future<GroupInvite> sendInvite(String groupId, String emailOrUsername) async {
    final response = await _apiClient.post(
      ApiConstants.sendInvite(groupId),
      body: {'email_or_username': emailOrUsername},
      headers: await _secureStorage.authHeaders(),
    );
    return _parseInvite(response);
  }

  Future<List<GroupInvite>> getMyInvites() async {
    final response = await _apiClient.get(
      ApiConstants.myInvites,
      headers: await _secureStorage.authHeaders(),
    );
    final data = response['data'];
    if (data is! List) return [];
    return data.whereType<Map<String, dynamic>>().map(GroupInvite.fromJson).toList();
  }

  Future<GroupInvite> respondToInvite(String inviteId, {required bool accept}) async {
    final response = await _apiClient.post(
      ApiConstants.respondInvite(inviteId, accept),
      headers: await _secureStorage.authHeaders(),
    );
    return _parseInvite(response);
  }

  GroupInvite _parseInvite(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw ApiException('Unexpected response from server.');
    }
    return GroupInvite.fromJson(data);
  }

  GroupResponse _parseGroup(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw ApiException('Unexpected response from server.');
    }
    return GroupResponse.fromJson(data);
  }
}

final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  return GroupRepository(
    apiClient: ref.watch(apiClientProvider),
    secureStorage: ref.watch(secureStorageServiceProvider),
  );
});
