from enum import Enum

class GroupStatus(str, Enum):
    ACTIVE = "active"
    PAUSED = "paused"
    COMPLETED = "completed"

class ShortfallPolicy(str, Enum):
    HOLD = "hold"
    PARTIAL = "partial"
    ADMIN_DECIDES = "admin_decides"

class MembershipStatus(str, Enum):
    INVITED = "invited"
    ACTIVE = "active"
    REMOVED = "removed"

class KYCStatus(str, Enum):
    PENDING = "pending"
    MOCKED_VERIFIED = "mocked_verified"
    MOCKED_FAILED = "mocked_failed"

class ContributionStatus(str, Enum):
    CONFIRMED = "confirmed"

class PayoutStatus(str, Enum):
    PENDING_AUTHORIZATION = "pending_authorization"
    SUCCESS = "success"
    FAILED = "failed"

class TransactionType(str, Enum):
    WALLET_FUNDING = "wallet_funding"
    GROUP_CONTRIBUTION = "group_contribution"
    PAYOUT = "payout"
    WITHDRAWAL = "withdrawal"

class TransactionStatus(str, Enum):
    PENDING = "pending"
    COMPLETED = "completed"
    FAILED = "failed"

class SwapRequestStatus(str, Enum):
    PENDING = "pending"
    ACCEPTED = "accepted"
    REJECTED = "rejected"
