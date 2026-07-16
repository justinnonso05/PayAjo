from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.types import String, Boolean
from sqlalchemy import ForeignKey
from datetime import datetime
from app.common.models import Base, UUIDMixin, TimestampMixin


class OTPCode(Base, UUIDMixin, TimestampMixin):
    """
    Stores hashed OTPs for high-risk, low-frequency actions only:
      - PIN reset (user has forgotten PIN)
      - Changing registered payout bank account
    Frequent in-app actions (wallet-to-group transfers, swap acceptance, delegation)
    use the transaction PIN instead — instant, no delivery dependency.
    """
    __tablename__ = "otp_codes"

    user_id: Mapped[str] = mapped_column(
        String, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )

    # What this OTP authorizes: "pin_reset" | "bank_change"
    purpose: Mapped[str] = mapped_column(String(50), nullable=False)

    # Bcrypt hash of the 6-digit code (never store plaintext)
    code_hash: Mapped[str] = mapped_column(String(255), nullable=False)

    # When this OTP expires
    expires_at: Mapped[datetime] = mapped_column(nullable=False)

    # Consumed once, then invalidated
    used: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
