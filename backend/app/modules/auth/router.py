from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import get_current_user
from app.common.schemas import BaseResponse
from app.modules.user.models import User
from .schemas import (
    SignupRequest, LoginRequest,
    SetupPinRequest, ResetPinRequest,
    TokenResponse,
)
from .service import (
    register_user, login_user,
    setup_user_pin, request_pin_reset, reset_pin_with_otp,
)
from app.modules.user.schemas import UserResponse

router = APIRouter(prefix="/auth", tags=["Auth"])


@router.post(
    "/signup",
    response_model=BaseResponse[TokenResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Register a new user",
)
async def signup(data: SignupRequest, db: AsyncSession = Depends(get_db)):
    """
    Register a new PayAjo user.
    - Creates user record in DB.
    - Calls Monnify to generate a Personal Reserved Account (Personal Wallet).
    - Sends welcome email via Brevo.
    - Returns a JWT access token.
    """
    result = await register_user(data, db)
    return BaseResponse(
        success=True,
        message="Account created successfully",
        data=TokenResponse(access_token=result["token"])
    )


@router.post(
    "/login",
    response_model=BaseResponse[TokenResponse],
    summary="Login with email and password",
)
async def login(data: LoginRequest, db: AsyncSession = Depends(get_db)):
    """Authenticate an existing user and return a JWT access token."""
    result = await login_user(data, db)
    return BaseResponse(
        success=True,
        message="Login successful",
        data=TokenResponse(access_token=result["token"])
    )


@router.post(
    "/setup-pin",
    response_model=BaseResponse[None],
    summary="Set your 4-digit transaction PIN (first time only)",
)
async def setup_pin(
    data: SetupPinRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Set the user's 4-digit transaction PIN.
    Required to authorize: wallet-to-group transfers, swap acceptance, delegation.
    Can only be set once. Use /auth/request-pin-reset to change it.
    """
    await setup_user_pin(current_user, data.pin, db)
    return BaseResponse(success=True, message="Transaction PIN set successfully", data=None)


@router.post(
    "/request-pin-reset",
    response_model=BaseResponse[None],
    summary="Request a PIN reset OTP (sends to registered email)",
)
async def request_reset(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Step 1 of PIN reset. Sends a 6-digit OTP to the user's registered email.
    OTP is used here (not PIN) because you need an independent identity check
    when the PIN itself has been forgotten.
    """
    await request_pin_reset(current_user, db)
    return BaseResponse(
        success=True,
        message=f"Verification code sent to {current_user.email}",
        data=None
    )


@router.post(
    "/reset-pin",
    response_model=BaseResponse[None],
    summary="Reset PIN using OTP from email",
)
async def reset_pin(
    data: ResetPinRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Step 2 of PIN reset. Verifies the OTP then sets the new PIN.
    OTP expires after 10 minutes and can only be used once.
    """
    await reset_pin_with_otp(current_user, data.otp_code, data.new_pin, db)
    return BaseResponse(success=True, message="Transaction PIN updated successfully", data=None)
