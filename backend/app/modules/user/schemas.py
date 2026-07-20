from pydantic import BaseModel, EmailStr, field_validator
from typing import Optional
from datetime import datetime
from decimal import Decimal


class UserResponse(BaseModel):
    id: str
    username: str
    first_name: str
    last_name: str
    email: str
    phone: Optional[str] = None
    avatar_url: Optional[str] = None

    # Wallet
    wallet_balance: Decimal
    personal_reserved_account_number: Optional[str] = None
    personal_reserved_account_bank: Optional[str] = None
    personal_reserved_account_name: Optional[str] = None
    
    # KYC & Security status
    kyc_status: bool
    has_wallet: bool
    has_pin: bool = False

    # Payout bank (validated external account — set via OTP-gated endpoint)
    payout_bank_account_number: Optional[str] = None
    payout_bank_code: Optional[str] = None
    payout_account_name: Optional[str] = None

    has_pin: bool = False

    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True

    @classmethod
    def from_orm_with_pin(cls, user) -> "UserResponse":
        obj = cls.model_validate(user)
        obj.has_pin = bool(user.pin_hash)
        return obj

class UserUpdate(BaseModel):
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    phone: Optional[str] = None

class SetPayoutBankRequest(BaseModel):
    """
    OTP-gated payout bank change.
    Requires an OTP from /users/me/payout-bank/request-otp to proceed.
    """
    bank_account_number: str
    bank_code: str
    otp_code: str


class MockKycRequest(BaseModel):
    """
    Request payload for the mock KYC and wallet creation step.
    BVN is only used to simulate the KYC check (we don't store it).
    """
    bvn: str
    
    @field_validator("bvn")
    @classmethod
    def validate_bvn(cls, v: str) -> str:
        if not v.isdigit() or len(v) != 11:
            raise ValueError("BVN must be exactly 11 digits")
        return v

class WalletLedgerEntryResponse(BaseModel):
    id: str
    user_id: str
    type: str
    amount: float
    related_group_id: Optional[str] = None
    related_contribution_id: Optional[str] = None
    monnify_transaction_reference: Optional[str] = None
    monnify_payment_reference: Optional[str] = None
    narration: Optional[str] = None
    created_at: datetime
    
    class Config:
        from_attributes = True

class TransactionReceiptResponse(BaseModel):
    transaction_id: str
    type: str
    amount: float
    status: str
    date: datetime
    sender_name: Optional[str] = None
    recipient_name: Optional[str] = None
    narration: Optional[str] = None
    reference: Optional[str] = None

class WithdrawRequest(BaseModel):
    amount: float
    pin: str

class WalletTransferRequest(BaseModel):
    """Send money from your wallet to another PayAjo user's wallet."""
    recipient_account_number: str
    amount: float
    pin: str
    narration: Optional[str] = None

class UserByAccountResponse(BaseModel):
    """Public profile returned when looking up a user by their reserved account number."""
    id: str
    first_name: str
    last_name: str
    username: str
    personal_reserved_account_number: str
    personal_reserved_account_name: Optional[str] = None

    class Config:
        from_attributes = True


class UserGroupMembershipResponse(BaseModel):
    # Membership info
    membership_id: str
    is_admin: bool
    membership_status: str
    joined_at: datetime
    
    # Group info
    group_id: str
    group_name: str
    contribution_amount: float
    cycle_frequency: str
    group_status: str
    pool_balance: float
    
    class Config:
        from_attributes = True

class UserSearchResponse(BaseModel):
    id: str
    username: str
    first_name: str
    last_name: str
    risk_score: int
    risk_factors: Optional[str] = None
    
    class Config:
        from_attributes = True
