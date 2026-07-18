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

  const GroupMember({
    required this.id,
    required this.userId,
    required this.isAdmin,
    required this.status,
    required this.joinedAt,
    required this.firstName,
    required this.lastName,
    required this.username,
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
    );
  }
}

/// From `GET /groups/{id}/members/pending`. Note this endpoint returns a
/// leaner shape than `GET /groups/{id}/members` — no first/last name or
/// username, just the raw membership record. The UI has to fall back to
/// showing a partial user id since there's no display name available.
class PendingMembership {
  final String id;
  final String groupId;
  final String userId;
  final String kycStatus;
  final String status;
  final DateTime createdAt;

  const PendingMembership({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.kycStatus,
    required this.status,
    required this.createdAt,
  });

  factory PendingMembership.fromJson(Map<String, dynamic> json) {
    return PendingMembership(
      id: json['id']?.toString() ?? '',
      groupId: json['group_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      kycStatus: json['kyc_status']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
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
