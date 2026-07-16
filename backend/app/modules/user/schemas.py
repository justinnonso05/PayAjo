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

