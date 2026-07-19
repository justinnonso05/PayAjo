enum CycleFrequency {
  weekly,
  monthly,
  yearly;

  String get apiValue => name;

  String get label {
    switch (this) {
      case CycleFrequency.weekly:
        return 'Weekly';
      case CycleFrequency.monthly:
        return 'Monthly';
      case CycleFrequency.yearly:
        return 'Yearly';
    }
  }

  static CycleFrequency? fromApiValue(String? value) {
    for (final freq in CycleFrequency.values) {
      if (freq.apiValue == value) return freq;
    }
    return null;
  }
}

enum ShortfallPolicy {
  hold,
  partial,
  adminDecides;

  String get apiValue {
    switch (this) {
      case ShortfallPolicy.hold:
        return 'hold';
      case ShortfallPolicy.partial:
        return 'partial';
      case ShortfallPolicy.adminDecides:
        return 'admin_decides';
    }
  }

  String get label {
    switch (this) {
      case ShortfallPolicy.hold:
        return 'Hold payout';
      case ShortfallPolicy.partial:
        return 'Pay out partially';
      case ShortfallPolicy.adminDecides:
        return 'Admin decides';
    }
  }

  String get description {
    switch (this) {
      case ShortfallPolicy.hold:
        return "Pause the payout until everyone's contribution is in.";
      case ShortfallPolicy.partial:
        return 'Pay out whatever has been contributed so far.';
      case ShortfallPolicy.adminDecides:
        return "You'll choose what happens each time it comes up.";
    }
  }
}

/// Payload for `POST /api/v1/groups/`.
/// Only the fields the backend actually requires are non-nullable;
/// payout-day fields are optional and only make sense for their
/// matching [cycleFrequency].
class GroupCreateRequest {
  final String name;
  final double contributionAmount;
  final CycleFrequency cycleFrequency;
  final ShortfallPolicy shortfallPolicy;
  final int? payoutDayOfWeek;
  final int? payoutDayOfMonth;
  final int? payoutMonth;
  final int? memberCap;
  final String? payoutTime;

  const GroupCreateRequest({
    required this.name,
    required this.contributionAmount,
    required this.cycleFrequency,
    required this.shortfallPolicy,
    this.payoutDayOfWeek,
    this.payoutDayOfMonth,
    this.payoutMonth,
    this.memberCap,
    this.payoutTime,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'contribution_amount': contributionAmount,
        'cycle_frequency': cycleFrequency.apiValue,
        'shortfall_policy': shortfallPolicy.apiValue,
        if (payoutDayOfWeek != null) 'payout_day_of_week': payoutDayOfWeek,
        if (payoutDayOfMonth != null) 'payout_day_of_month': payoutDayOfMonth,
        if (payoutMonth != null) 'payout_month': payoutMonth,
        if (memberCap != null) 'member_cap': memberCap,
        if (payoutTime != null) 'payout_time': payoutTime,
      };
}

class GroupResponse {
  final String id;
  final String name;
  final double contributionAmount;
  final CycleFrequency? cycleFrequency;
  final int quorumPercent;
  final ShortfallPolicy? shortfallPolicy;
  final String status;
  final String adminUserId;
  final String? inviteCode;
  final bool inviteCodeActive;
  final double poolBalance;
  final int? memberCap;
  final int currentCycleNumber;
  final int currentRotationIndex;
  final DateTime? createdAt;
  final DateTime? startedAt;
  final DateTime? nextPayoutDate;
  final DateTime? updatedAt;

  const GroupResponse({
    required this.id,
    required this.name,
    required this.contributionAmount,
    required this.cycleFrequency,
    required this.quorumPercent,
    required this.shortfallPolicy,
    required this.status,
    required this.adminUserId,
    required this.inviteCode,
    required this.inviteCodeActive,
    required this.poolBalance,
    required this.memberCap,
    required this.currentCycleNumber,
    required this.currentRotationIndex,
    required this.createdAt,
    required this.startedAt,
    required this.nextPayoutDate,
    required this.updatedAt,
  });

  factory GroupResponse.fromJson(Map<String, dynamic> json) {
    return GroupResponse(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      contributionAmount: (json['contribution_amount'] as num?)?.toDouble() ?? 0,
      cycleFrequency: CycleFrequency.fromApiValue(json['cycle_frequency']?.toString()),
      quorumPercent: (json['quorum_percent'] as num?)?.toInt() ?? 0,
      shortfallPolicy: _shortfallFromApiValue(json['shortfall_policy']?.toString()),
      status: json['status']?.toString() ?? '',
      adminUserId: json['admin_user_id']?.toString() ?? '',
      inviteCode: json['invite_code']?.toString(),
      inviteCodeActive: json['invite_code_active'] == true,
      poolBalance: (json['pool_balance'] as num?)?.toDouble() ?? 0,
      memberCap: (json['member_cap'] as num?)?.toInt(),
      currentCycleNumber: (json['current_cycle_number'] as num?)?.toInt() ?? 0,
      currentRotationIndex: (json['current_rotation_index'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      startedAt: DateTime.tryParse(json['started_at']?.toString() ?? ''),
      nextPayoutDate: DateTime.tryParse(json['next_payout_date']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
    );
  }

  static ShortfallPolicy? _shortfallFromApiValue(String? value) {
    for (final policy in ShortfallPolicy.values) {
      if (policy.apiValue == value) return policy;
    }
    return null;
  }
}

/// From `GET /users/me/groups` — a lighter summary of each group the
/// current user belongs to.
class UserGroupMembership {
  final String membershipId;
  final bool isAdmin;
  final String membershipStatus;
  final DateTime joinedAt;
  final String groupId;
  final String groupName;
  final double contributionAmount;
  final CycleFrequency? cycleFrequency;
  final String groupStatus;
  final double poolBalance;

  const UserGroupMembership({
    required this.membershipId,
    required this.isAdmin,
    required this.membershipStatus,
    required this.joinedAt,
    required this.groupId,
    required this.groupName,
    required this.contributionAmount,
    required this.cycleFrequency,
    required this.groupStatus,
    required this.poolBalance,
  });

  factory UserGroupMembership.fromJson(Map<String, dynamic> json) {
    return UserGroupMembership(
      membershipId: json['membership_id']?.toString() ?? '',
      isAdmin: json['is_admin'] == true,
      membershipStatus: json['membership_status']?.toString() ?? '',
      joinedAt: DateTime.tryParse(json['joined_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      groupId: json['group_id']?.toString() ?? '',
      groupName: json['group_name']?.toString() ?? '',
      contributionAmount: (json['contribution_amount'] as num?)?.toDouble() ?? 0,
      cycleFrequency: CycleFrequency.fromApiValue(json['cycle_frequency']?.toString()),
      groupStatus: json['group_status']?.toString() ?? '',
      poolBalance: (json['pool_balance'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// From `GET /groups/{id}/members`.
class GroupMember {
  final String id;
  final String userId;
  final bool isAdmin;
  final String status;
  final DateTime joinedAt;
  final String firstName;
  final String lastName;
  final String username;
  final bool hasPaidCurrentCycle;
  final int? payoutPosition;
  final bool autoDebitEnabled;
  final int autoDebitDaysBefore;

  const GroupMember({
    required this.id,
    required this.userId,
    required this.isAdmin,
    required this.status,
    required this.joinedAt,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.hasPaidCurrentCycle,
    required this.payoutPosition,
    required this.autoDebitEnabled,
    required this.autoDebitDaysBefore,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      isAdmin: json['is_admin'] == true,
      status: json['status']?.toString() ?? '',
      joinedAt: DateTime.tryParse(json['joined_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      hasPaidCurrentCycle: json['has_paid_current_cycle'] == true,
      payoutPosition: (json['payout_position'] as num?)?.toInt(),
      autoDebitEnabled: json['auto_debit_enabled'] == true,
      autoDebitDaysBefore: (json['auto_debit_days_before'] as num?)?.toInt() ?? 1,
    );
  }
}

/// From `GET /groups/{id}/rotations` — the full ordered payout schedule.
class GroupRotationEntry {
  final int cycleNumber;
  final String userId;
  final String firstName;
  final String lastName;
  final String username;
  final DateTime? payoutDate;
  final bool isCompleted;
  final bool isCurrent;

  const GroupRotationEntry({
    required this.cycleNumber,
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.payoutDate,
    required this.isCompleted,
    required this.isCurrent,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory GroupRotationEntry.fromJson(Map<String, dynamic> json) {
    return GroupRotationEntry(
      cycleNumber: (json['cycle_number'] as num?)?.toInt() ?? 0,
      userId: json['user_id']?.toString() ?? '',
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      payoutDate: DateTime.tryParse(json['payout_date']?.toString() ?? ''),
      isCompleted: json['is_completed'] == true,
      isCurrent: json['is_current'] == true,
    );
  }
}

/// From `GET /groups/{id}/members/pending` — despite the leaner name, this
/// actually returns the same `GroupMemberProfileResponse` shape as
/// `GET /groups/{id}/members` (first/last name, username, `joined_at`, no
/// `created_at`), per the OpenAPI spec.
class PendingMembership {
  final String id;
  final String groupId;
  final String userId;
  final String status;
  final String firstName;
  final String lastName;
  final String username;
  final DateTime joinedAt;

  const PendingMembership({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.status,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.joinedAt,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory PendingMembership.fromJson(Map<String, dynamic> json) {
    return PendingMembership(
      id: json['id']?.toString() ?? '',
      groupId: json['group_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      joinedAt: DateTime.tryParse(json['joined_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

/// Payload for `PATCH /groups/{id}` — every field is optional; only
/// fields that were actually changed should be included in [toJson].
class GroupUpdateRequest {
  final String? name;
  final double? contributionAmount;
  final CycleFrequency? cycleFrequency;
  final ShortfallPolicy? shortfallPolicy;
  final int? payoutDayOfWeek;
  final int? payoutDayOfMonth;
  final int? payoutMonth;
  final int? memberCap;
  final String? payoutTime;

  const GroupUpdateRequest({
    this.name,
    this.contributionAmount,
    this.cycleFrequency,
    this.shortfallPolicy,
    this.payoutDayOfWeek,
    this.payoutDayOfMonth,
    this.payoutMonth,
    this.memberCap,
    this.payoutTime,
  });

  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        if (contributionAmount != null) 'contribution_amount': contributionAmount,
        if (cycleFrequency != null) 'cycle_frequency': cycleFrequency!.apiValue,
        if (shortfallPolicy != null) 'shortfall_policy': shortfallPolicy!.apiValue,
        if (payoutDayOfWeek != null) 'payout_day_of_week': payoutDayOfWeek,
        if (payoutDayOfMonth != null) 'payout_day_of_month': payoutDayOfMonth,
        if (payoutMonth != null) 'payout_month': payoutMonth,
        if (payoutTime != null) 'payout_time': payoutTime,
        if (memberCap != null) 'member_cap': memberCap,
      };
}

/// A direct invite (by email/username), separate from the invite-code
/// join flow. Note the backend response has no group name or inviter
/// name — just raw ids — so the UI resolves the group name separately.
class GroupInvite {
  final String id;
  final String groupId;
  final String invitedUserId;
  final String invitedByUserId;
  final String status;
  final DateTime? resolvedAt;
  final DateTime createdAt;

  const GroupInvite({
    required this.id,
    required this.groupId,
    required this.invitedUserId,
    required this.invitedByUserId,
    required this.status,
    required this.resolvedAt,
    required this.createdAt,
  });

  bool get isPending => status.toLowerCase() == 'pending';

  factory GroupInvite.fromJson(Map<String, dynamic> json) {
    return GroupInvite(
      id: json['id']?.toString() ?? '',
      groupId: json['group_id']?.toString() ?? '',
      invitedUserId: json['invited_user_id']?.toString() ?? '',
      invitedByUserId: json['invited_by_user_id']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      resolvedAt: DateTime.tryParse(json['resolved_at']?.toString() ?? ''),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

/// A one-time direct payment (virtual account + hosted checkout link) for
/// a single contribution, generated via `generate-direct-payment`. The
/// virtual account and checkout link both expire after
/// [accountDurationSeconds] (currently 40 minutes / 2400s).
class DirectPaymentDetails {
  final String paymentReference;
  final String transactionReference;
  final String checkoutUrl;
  final double amount;
  final String accountNumber;
  final String bankName;
  final String bankCode;
  final String accountName;
  final DateTime expiresOn;
  final int accountDurationSeconds;

  const DirectPaymentDetails({
    required this.paymentReference,
    required this.transactionReference,
    required this.checkoutUrl,
    required this.amount,
    required this.accountNumber,
    required this.bankName,
    required this.bankCode,
    required this.accountName,
    required this.expiresOn,
    required this.accountDurationSeconds,
  });

  factory DirectPaymentDetails.fromJson(Map<String, dynamic> json) {
    return DirectPaymentDetails(
      paymentReference: json['paymentReference']?.toString() ?? '',
      transactionReference: json['transactionReference']?.toString() ?? '',
      checkoutUrl: json['checkoutUrl']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      accountNumber: json['accountNumber']?.toString() ?? '',
      bankName: json['bankName']?.toString() ?? '',
      bankCode: json['bankCode']?.toString() ?? '',
      accountName: json['accountName']?.toString() ?? '',
      expiresOn: DateTime.tryParse(json['expiresOn']?.toString() ?? '') ?? DateTime.now(),
      accountDurationSeconds: (json['accountDurationSeconds'] as num?)?.toInt() ?? 0,
    );
  }
}
