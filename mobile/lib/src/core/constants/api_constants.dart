import '../config/env_config.dart';

class ApiConstants {
  static String get baseUrl => EnvConfig.baseUrl;

  /// The backend versions all routes under this prefix, e.g.
  /// https://ajopay.fastapicloud.dev/api/v1/auth/signup
  static const String apiPrefix = '/api/v1';

  // Auth endpoints
  static String get login => '$apiPrefix/auth/login';
  static String get register => '$apiPrefix/auth/signup';
  static String get verifyOtp => '$apiPrefix/auth/verify-otp';
  static String get setupPin => '$apiPrefix/auth/setup-pin';
  static String get requestPinReset => '$apiPrefix/auth/request-pin-reset';
  static String get resetPin => '$apiPrefix/auth/reset-pin';

  // Group endpoints
  static String get groups => '$apiPrefix/groups/';
  static String get joinGroup => '$apiPrefix/groups/join';
  static String group(String groupId) => '$apiPrefix/groups/$groupId';
  static String groupMembers(String groupId) => '$apiPrefix/groups/$groupId/members';

  // User endpoints
  static String get me => '$apiPrefix/users/me';
  static String get myGroups => '$apiPrefix/users/me/groups';
  static String get mockKycVerify => '$apiPrefix/users/me/kyc/mock-verify';
  static String get bankAccount => '$apiPrefix/members/bank-account';

  // Wallet endpoints
  static String get walletTransactions => '$apiPrefix/users/me/wallet/transactions';
  static String get walletWithdraw => '$apiPrefix/users/me/wallet/withdraw';

  // Notification endpoints
  static String get notifications => '$apiPrefix/notifications';
  static String get markNotificationsRead => '$apiPrefix/notifications/mark-read';

  // Group action endpoints
  static String payFromWallet(String groupId) => '$apiPrefix/groups/$groupId/pay-from-wallet';

  // Group admin endpoints
  static String pendingMembers(String groupId) => '$apiPrefix/groups/$groupId/members/pending';
  static String approveMember(String groupId, String userId) => '$apiPrefix/groups/$groupId/members/$userId/approve';
  static String startGroup(String groupId) => '$apiPrefix/groups/$groupId/start';
  static String rotateInviteCode(String groupId) => '$apiPrefix/groups/$groupId/rotate-code';

  // Group invite endpoints (direct invite by username/email — separate
  // from the invite-code join flow)
  static String sendInvite(String groupId) => '$apiPrefix/groups/$groupId/invites';
  static String get myInvites => '$apiPrefix/groups/me/invites';
  static String respondInvite(String inviteId, bool accept) => '$apiPrefix/groups/invites/$inviteId/respond?accept=$accept';
}
