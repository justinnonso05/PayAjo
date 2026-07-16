from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.database import get_db
from app.common.schemas import BaseResponse
from app.modules.user.models import User
from app.core.security import get_current_user
from .schemas import GroupResponse, GroupCreate, JoinGroupRequest
from .service import create_group_service, join_group_service

router = APIRouter(prefix="/groups", tags=["Groups"])

@router.post("/join", response_model=BaseResponse[GroupResponse])
async def join_group(
    data: JoinGroupRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Join a group using a shareable invite code.
    """
    group = await join_group_service(current_user, data.invite_code, db)
    return BaseResponse(
        success=True,
        message="Successfully joined the group",
        data=group
    )

@router.post("/", response_model=BaseResponse[GroupResponse])
async def create_group(
    group: GroupCreate, 
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    new_group = await create_group_service(current_user, group, db)
    return BaseResponse(
        success=True,
        message="Group created successfully",
        data=new_group
    )

@router.get("/{group_id}", response_model=BaseResponse[GroupResponse])
async def get_group(group_id: str, db: AsyncSession = Depends(get_db)):
    # TODO: Implement fetch logic
    return BaseResponse(
        success=True,
        message="Group retrieved successfully",
        data=None
    )
