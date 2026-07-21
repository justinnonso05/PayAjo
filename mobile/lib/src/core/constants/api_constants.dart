import '../config/env_config.dart';

class ApiConstants {
  static String get baseUrl => EnvConfig.baseUrl;

  /// The backend versions all routes under this prefix, e.g.
  /// https://payajo.fastapicloud.dev/api/v1/auth/signup
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
  static String groupRotations(String groupId) => '$apiPrefix/groups/$groupId/rotations';
  static String autoDebit(String groupId) => '$apiPrefix/groups/$groupId/auto-debit';

  // Cycle management — delegating or swapping a payout turn. Note: unlike
  // the other group endpoints, these live under /cycles, not /groups.
  static String delegateCycle(String groupId, int cycleNumber) => '$apiPrefix/cycles/$groupId/cycles/$cycleNumber/delegate';
  static String swapCycle(String groupId) => '$apiPrefix/cycles/$groupId/swap';
  static String pendingSwaps(String groupId) => '$apiPrefix/cycles/$groupId/swaps/pending';
  static String pendingDelegations(String groupId) => '$apiPrefix/cycles/$groupId/delegations/pending';
  static String respondSwap(String groupId, String swapId) => '$apiPrefix/cycles/$groupId/swaps/$swapId/respond';
  static String approveSwap(String groupId, String swapId) => '$apiPrefix/cycles/$groupId/swaps/$swapId/approve';
  static String approveDelegation(String groupId, String delegationId) => '$apiPrefix/cycles/$groupId/delegations/$delegationId/approve';

  // User endpoints
  static String get me => '$apiPrefix/users/me';
  static String get avatar => '$apiPrefix/users/me/avatar';
  static String get myGroups => '$apiPrefix/users/me/groups';
  static String get mockKycVerify => '$apiPrefix/users/me/kyc/mock-verify';
  static String get bankAccount => '$apiPrefix/members/bank-account';

  // Search for a user by exact email or username — used to preview who
  // you're inviting (name + risk score) before sending a direct invite.
  static String searchUser(String query) => '$apiPrefix/users/search?q=${Uri.encodeQueryComponent(query)}';

  // Wallet endpoints
  static String get walletTransactions => '$apiPrefix/users/me/wallet/transactions';
  static String walletTransactionReceipt(String transactionId) => '$apiPrefix/users/me/wallet/transactions/$transactionId';
  static String get walletWithdraw => '$apiPrefix/users/me/wallet/withdraw';
  static String walletLookup(String accountNumber) => '$apiPrefix/users/me/wallet/lookup?account_number=$accountNumber';
  static String get walletTransfer => '$apiPrefix/users/me/wallet/transfer';

  // Transaction status polling (checks whether a Monnify webhook — wallet
  // top-up or dynamic virtual account group payment — has landed yet)
  static String transactionStatus(String paymentReference) => '$apiPrefix/users/me/transactions/status/$paymentReference';

  // Payout bank endpoints
  static String get banks => '$apiPrefix/users/banks';
  static String validateBankAccount(String accountNumber, String bankCode) =>
      '$apiPrefix/users/banks/validate?account_number=$accountNumber&bank_code=$bankCode';
  static String get requestPayoutBankOtp => '$apiPrefix/users/me/payout-bank/request-otp';
  static String get setPayoutBank => '$apiPrefix/users/me/payout-bank';

  // Notification endpoints
  static String get notifications => '$apiPrefix/notifications';
  static String get markNotificationsRead => '$apiPrefix/notifications/mark-read';

  // Group action endpoints
  static String payFromWallet(String groupId) => '$apiPrefix/groups/$groupId/pay-from-wallet';
  static String generateDirectPayment(String groupId) => '$apiPrefix/groups/$groupId/generate-direct-payment';

  // Group admin endpoints
  static String pendingMembers(String groupId) => '$apiPrefix/groups/$groupId/members/pending';
  static String approveMember(String groupId, String userId) => '$apiPrefix/groups/$groupId/members/$userId/approve';
  static String startGroup(String groupId) => '$apiPrefix/groups/$groupId/start';
  static String rotateInviteCode(String groupId) => '$apiPrefix/groups/$groupId/rotate-code';
  static String sendMemberReminder(String groupId, String userId) => '$apiPrefix/groups/$groupId/members/$userId/send-reminder';
  static String sendRemindersBulk(String groupId) => '$apiPrefix/groups/$groupId/send-reminders-bulk';

  // Manually runs the payout scheduler across ALL groups (not scoped to
  // one group) — for testing/demo so payouts don't need to wait for the
  // real cron interval.
  static String get triggerScheduler => '$apiPrefix/cycles/admin/trigger-scheduler';

  // Group invite endpoints (direct invite by username/email — separate
  // from the invite-code join flow)
  static String sendInvite(String groupId) => '$apiPrefix/groups/$groupId/invites';
  static String get myInvites => '$apiPrefix/groups/me/invites';
  static String respondInvite(String inviteId, bool accept) => '$apiPrefix/groups/invites/$inviteId/respond?accept=$accept';

  // Group chat endpoints
  static String chatHistory(String groupId, {int limit = 50, int offset = 0}) =>
      '$apiPrefix/groups/$groupId/chat?limit=$limit&offset=$offset';
  static String chatWebSocket(String groupId, String token) => '$apiPrefix/groups/$groupId/ws?token=$token';
  static String chatImage(String groupId) => '$apiPrefix/groups/$groupId/chat/image';
}
