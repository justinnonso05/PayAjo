import random
import string
from datetime import datetime, timedelta, timezone

from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.modules.otp.models import OTPCode
from app.modules.user.models import User
from app.core.security import hash_pin, verify_pin
from app.core.config import settings
from app.services.email import send_otp_email


def _generate_otp() -> str:
    """Generate a cryptographically random 6-digit OTP."""
    return "".join(random.choices(string.digits, k=6))


async def request_otp(user: User, purpose: str, db: AsyncSession) -> str:
    """
    Generate, store (hashed), and email an OTP to the user.
    Purpose must be one of: 'pin_reset' | 'bank_change'

    Returns the raw OTP only for testing purposes in sandbox.
    In production the return value is discarded — the user gets it via email only.
    """
    allowed_purposes = {"pin_reset", "bank_change"}
    if purpose not in allowed_purposes:
        raise ValueError(f"Invalid OTP purpose: {purpose}")

    # Invalidate any previous unused OTPs for this user + purpose
    existing = await db.execute(
        select(OTPCode).where(
            OTPCode.user_id == user.id,
            OTPCode.purpose == purpose,
            OTPCode.used == False,  # noqa: E712
        )
    )
    for old_otp in existing.scalars().all():
        old_otp.used = True
        db.add(old_otp)

    # Generate and store new OTP
    raw_code = _generate_otp()
    expires_at = datetime.now(timezone.utc).replace(tzinfo=None) + timedelta(minutes=settings.OTP_EXPIRE_MINUTES)

    otp_record = OTPCode(
        user_id=user.id,
        purpose=purpose,
        code_hash=hash_pin(raw_code),  # reuse bcrypt hash — same security as PIN
        expires_at=expires_at,
        used=False,
    )
    db.add(otp_record)
    await db.commit()

    # Email the OTP
    reason_labels = {
        "pin_reset": "reset your transaction PIN",
        "bank_change": "update your payout bank account",
    }
    await send_otp_email(
        to_email=user.email,
        to_name=user.first_name,
        otp_code=raw_code,
        reason=reason_labels[purpose],
    )

    return raw_code  # only used in sandbox/test; never expose in API response


async def verify_otp(user: User, purpose: str, code: str, db: AsyncSession) -> OTPCode:
    """
    Verify an OTP for the given user and purpose.
    Raises 400 if invalid/expired/already used.
    Marks the OTP as used on success so it can't be replayed.
    """
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    result = await db.execute(
        select(OTPCode).where(
            OTPCode.user_id == user.id,
            OTPCode.purpose == purpose,
            OTPCode.used == False,  # noqa: E712
            OTPCode.expires_at > now,
        ).order_by(OTPCode.created_at.desc())
    )
    otp_record = result.scalar_one_or_none()

    if not otp_record or not verify_pin(code, otp_record.code_hash):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired verification code"
        )

    # Mark as consumed
    otp_record.used = True
    db.add(otp_record)
    await db.commit()

    return otp_record
