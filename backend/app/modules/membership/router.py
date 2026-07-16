from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.database import get_db
from app.common.schemas import BaseResponse
from .schemas import MembershipResponse, MembershipCreate

router = APIRouter(prefix="/memberships", tags=["Memberships"])

@router.post("/", response_model=BaseResponse[MembershipResponse])
async def create_membership(membership: MembershipCreate, db: AsyncSession = Depends(get_db)):
    # TODO: Implement creation logic
    return BaseResponse(
        success=True,
        message="Membership created successfully",
        data=None
    )
