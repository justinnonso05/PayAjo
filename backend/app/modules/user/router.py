from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from typing import Any

from app.core.database import get_db
from app.core.security import get_current_user
from app.common.schemas import BaseResponse
from app.modules.user.models import User
from .schemas import UserResponse, SetPayoutBankRequest, MockKycRequest
from .service import request_bank_change_otp, set_payout_bank, get_banks_list, mock_kyc_and_create_wallet

router = APIRouter(prefix="/users", tags=["Users"])


@router.post(
    "/me/kyc/mock-verify",
    response_model=BaseResponse[UserResponse],
    summary="Mock KYC verification and Wallet Creation",
)
async def verify_kyc(
    data: MockKycRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Step 2 of Onboarding: Verifies the user's BVN (mock) and generates 
    their Personal Reserved Account on Monnify.
    Updates the user's kyc_status and has_wallet flags.
    """
    updated_user = await mock_kyc_and_create_wallet(current_user, data.bvn, db)
    return BaseResponse(
        success=True,
        message="KYC verified and personal wallet created successfully",
        data=UserResponse.from_orm_with_pin(updated_user)
    )

@router.get(
    "/me",
    response_model=BaseResponse[UserResponse],
    summary="Get current user profile",
)
async def get_me(current_user: User = Depends(get_current_user)):
    """
    Returns the authenticated user's full profile including:
    - Wallet balance
    - Personal reserved account (for topping up wallet)
    - Payout bank details
    - Whether a transaction PIN is set
    """
    return BaseResponse(
        success=True,
        message="Profile fetched successfully",
        data=UserResponse.from_orm_with_pin(current_user)
    )


@router.post(
    "/me/payout-bank/request-otp",
    response_model=BaseResponse[None],
    summary="Step 1: Request OTP to change payout bank",
)
async def request_payout_bank_otp(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Sends a 6-digit OTP to the user's registered email.
    Required before updating the payout bank account.

    OTP is used (not PIN) because the payout bank determines where real money
    eventually lands — a high-consequence action requiring independent channel proof.
    """
    await request_bank_change_otp(current_user, db)
    return BaseResponse(
        success=True,
        message=f"Verification code sent to {current_user.email}",
        data=None
    )


@router.post(
    "/me/payout-bank",
    response_model=BaseResponse[UserResponse],
    summary="Step 2: Set and validate payout bank account (OTP required)",
)
async def update_payout_bank(
    data: SetPayoutBankRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Verifies the OTP, calls Monnify Name Enquiry to validate the account,
    then saves the resolved account details.

    The user sees the resolved account name (e.g. 'CHIDI OKAFOR') before
    this endpoint is called — the frontend should run a Name Enquiry preview
    first via GET /users/banks/validate, then submit with the OTP to confirm.
    """
    updated_user = await set_payout_bank(current_user, data, db)
    return BaseResponse(
        success=True,
        message=f"Payout account set to {updated_user.payout_account_name}",
        data=UserResponse.from_orm_with_pin(updated_user)
    )


from app.services.monnify import monnify_client

@router.get(
    "/banks/validate",
    response_model=BaseResponse[Any],
    summary="Validate bank account details (Name Enquiry)",
)
async def validate_bank_account(
    account_number: str,
    bank_code: str,
):
    """
    Calls Monnify Name Enquiry to resolve the account name.
    The frontend calls this *before* submitting the OTP to confirm.
    """
    try:
        enquiry = await monnify_client.validate_bank_account(
            account_number=account_number,
            bank_code=bank_code,
        )
        return BaseResponse(
            success=True,
            message="Account validated successfully",
            data=enquiry
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Bank account validation failed: {str(e)}"
        )


@router.get(
    "/banks",
    response_model=BaseResponse[Any],
    summary="Get list of supported banks",
)
async def list_banks():
    """
    Returns Monnify's full list of banks for the bank picker UI.
    No authentication required.
    """
    banks = await get_banks_list()
    return BaseResponse(
        success=True,
        message="Banks fetched successfully",
        data=banks
    )
