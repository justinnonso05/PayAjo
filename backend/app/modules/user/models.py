from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.types import String, Numeric, Boolean
from typing import Optional
from app.common.models import Base, UUIDMixin, TimestampMixin

class User(Base, UUIDMixin, TimestampMixin):
    __tablename__ = "users"

    # Identity
    username: Mapped[str] = mapped_column(String(100), unique=True, index=True, nullable=False)
    first_name: Mapped[str] = mapped_column(String(100), nullable=False)
    last_name: Mapped[str] = mapped_column(String(100), nullable=False)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True, nullable=False)
    phone: Mapped[str] = mapped_column(String(50), nullable=True)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)

    # Security
    pin_hash: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)

    # KYC status
    kyc_status: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    has_wallet: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    # Personal Wallet
    wallet_balance: Mapped[float] = mapped_column(Numeric(12, 2), default=0.00, nullable=False)
    personal_reserved_account_number: Mapped[str] = mapped_column(String(50), nullable=True)
    personal_reserved_account_bank: Mapped[str] = mapped_column(String(100), nullable=True)
    personal_reserved_account_name: Mapped[str] = mapped_column(String(255), nullable=True)
    personal_reserved_account_reference: Mapped[str] = mapped_column(String(255), nullable=True)

    # External Payout Bank (validated via Monnify Name Enquiry at onboarding)
    payout_bank_account_number: Mapped[str] = mapped_column(String(50), nullable=True)
    payout_bank_code: Mapped[str] = mapped_column(String(10), nullable=True)
    payout_account_name: Mapped[str] = mapped_column(String(255), nullable=True)
