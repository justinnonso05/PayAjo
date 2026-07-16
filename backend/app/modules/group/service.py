import random
import string
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from fastapi import HTTPException, status

from app.modules.user.models import User
from app.modules.group.models import Group
from app.modules.membership.models import Membership
from app.modules.group.schemas import GroupCreate
from app.common.enums import GroupStatus, MembershipStatus, KYCStatus

def generate_invite_code(length: int = 6) -> str:
    """Generate a random alphanumeric invite code."""
    return ''.join(random.choices(string.ascii_uppercase + string.digits, k=length))

async def create_group_service(user: User, data: GroupCreate, db: AsyncSession) -> Group:
    """
    Creates a new Group and automatically adds the creator as an active Admin.
    """
    # 1. Create the Group
    new_group = Group(
        name=data.name,
        admin_user_id=user.id,
        contribution_amount=data.contribution_amount,
        cycle_frequency=data.cycle_frequency,
        payout_day_of_week=data.payout_day_of_week,
        payout_day_of_month=data.payout_day_of_month,
        payout_month=data.payout_month,
        payout_day_override=data.payout_day_override,
        quorum_percent=data.quorum_percent,
        shortfall_policy=data.shortfall_policy,
        requires_approval_for_delegate=data.requires_approval_for_delegate,
        requires_approval_for_swap=data.requires_approval_for_swap,
        invite_code=generate_invite_code(),
        invite_code_active=True,
        pool_balance=0.00,
        member_cap=data.member_cap,
        status=GroupStatus.ACTIVE
    )
    db.add(new_group)
    
    # flush to get the new_group.id
    await db.flush()

    # 2. Add the Admin Membership
    admin_membership = Membership(
        group_id=new_group.id,
        user_id=user.id,
        is_admin=True,
        kyc_status=KYCStatus.MOCKED_VERIFIED if user.kyc_status else KYCStatus.PENDING,
        status=MembershipStatus.ACTIVE
    )
    db.add(admin_membership)

    await db.commit()
    await db.refresh(new_group)

    return new_group

async def join_group_service(user: User, invite_code: str, db: AsyncSession) -> Group:
    """
    Allows a user to join a group using an invite code.
    """
    # 1. Find group by invite code
    result = await db.execute(
        select(Group).where(
            Group.invite_code == invite_code,
            Group.invite_code_active == True # noqa: E712
        )
    )
    group = result.scalar_one_or_none()
    
    if not group:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Invalid or inactive invite code"
        )
        
    # 2. Check if already a member
    membership_result = await db.execute(
        select(Membership).where(
            Membership.group_id == group.id,
            Membership.user_id == user.id
        )
    )
    if membership_result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You are already a member of this group"
        )
        
    # 3. Check member cap
    if group.member_cap:
        count_result = await db.execute(
            select(func.count()).where(
                Membership.group_id == group.id,
                Membership.status == MembershipStatus.ACTIVE
            )
        )
        current_members = count_result.scalar() or 0
        if current_members >= group.member_cap:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="This group has reached its maximum member capacity"
            )
            
    # 4. Create membership
    new_membership = Membership(
        group_id=group.id,
        user_id=user.id,
        is_admin=False,
        kyc_status=KYCStatus.MOCKED_VERIFIED if user.kyc_status else KYCStatus.PENDING,
        status=MembershipStatus.ACTIVE
    )
    db.add(new_membership)
    await db.commit()
    
    return group
