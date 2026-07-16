import uuid
from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.modules.user.models import User
from app.core.security import (
    hash_password, verify_password,
    hash_pin, verify_pin,
    create_access_token,
)
from app.services.monnify import monnify_client
from app.services.email import send_welcome_email
from app.modules.otp.service import request_otp, verify_otp
from .schemas import SignupRequest, LoginRequest


async def register_user(data: SignupRequest, db: AsyncSession) -> dict:
    """
    Full user registration flow:
    1. Check for duplicate email/username
    2. Hash password
    3. Save user to DB (without wallet yet, requires KYC step)
    4. Send welcome email
    5. Return JWT token
    """
    # 1. Duplicate checks
    existing_email = await db.execute(select(User).where(User.email == data.email))
    if existing_email.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="An account with this email already exists"
        )

    existing_username = await db.execute(select(User).where(User.username == data.username))
    if existing_username.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="This username is already taken"
        )

    # 2. Hash password
    password_hash = hash_password(data.password)

    # 3. Save user
    user_id = str(uuid.uuid4())
    new_user = User(
        id=user_id,
        username=data.username,
        first_name=data.first_name,
        last_name=data.last_name,
        email=data.email,
        phone=data.phone,
        password_hash=password_hash,
        wallet_balance=0.00,
        kyc_status=False,
        has_wallet=False,
    )
    db.add(new_user)
    await db.commit()
    await db.refresh(new_user)

    # 5. Welcome email (non-blocking)
    await send_welcome_email(
        to_email=new_user.email,
        to_name=new_user.first_name,
    )

    # 6. Issue JWT
    token = create_access_token(data={"sub": new_user.id})
    return {"user": new_user, "token": token}


async def login_user(data: LoginRequest, db: AsyncSession) -> dict:
    """Authenticate user, return JWT."""
    result = await db.execute(select(User).where(User.email == data.email))
    user = result.scalar_one_or_none()

    if not user or not verify_password(data.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password"
        )

    token = create_access_token(data={"sub": user.id})
    return {"user": user, "token": token}


async def setup_user_pin(user: User, pin: str, db: AsyncSession) -> User:
    """
    Set initial 4-digit transaction PIN (can only be set once).
    Used to authorize: wallet-to-group transfers, swap acceptance, delegation.
    For PIN reset, use request_pin_reset_otp + reset_pin_with_otp.
    """
    if user.pin_hash:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="PIN is already set. Use the reset-pin flow to change it."
        )
    user.pin_hash = hash_pin(pin)
    db.add(user)
    await db.commit()
    await db.refresh(user)
    return user


async def request_pin_reset(user: User, db: AsyncSession) -> None:
    """
    Step 1 of PIN reset: Send OTP to the user's registered email.
    OTP is used because you can't verify identity with the PIN if they've forgotten it.
    """
    await request_otp(user=user, purpose="pin_reset", db=db)


async def reset_pin_with_otp(user: User, otp_code: str, new_pin: str, db: AsyncSession) -> User:
    """
    Step 2 of PIN reset: Verify OTP then set the new PIN.
    """
    await verify_otp(user=user, purpose="pin_reset", code=otp_code, db=db)

    user.pin_hash = hash_pin(new_pin)
    db.add(user)
    await db.commit()
    await db.refresh(user)
    return user


def check_pin(user: User, pin: str) -> None:
    """
    Verify a submitted PIN for in-app actions.
    Raises 401 if the PIN is wrong or not set.
    """
    if not user.pin_hash:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Transaction PIN not set. Please set your PIN first."
        )
    if not verify_pin(pin, user.pin_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect transaction PIN"
        )
