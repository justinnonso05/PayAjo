from pydantic import BaseModel
from typing import Optional
from datetime import datetime
from app.common.enums import ShortfallPolicy, GroupStatus, CycleFrequency

class GroupBase(BaseModel):
    name: str
    contribution_amount: float
    
    cycle_frequency: CycleFrequency
    payout_day_of_week: Optional[int] = None
    payout_day_of_month: Optional[int] = None
    payout_month: Optional[int] = None
    payout_day_override: Optional[int] = None
    
    quorum_percent: int
    shortfall_policy: ShortfallPolicy
    
    requires_approval_for_delegate: bool = True
    requires_approval_for_swap: bool = True
    member_cap: Optional[int] = None

class GroupCreate(GroupBase):
    pass

class JoinGroupRequest(BaseModel):
    invite_code: str

class GroupResponse(GroupBase):
    id: str
    admin_user_id: str
    status: GroupStatus
    current_rotation_index: int
    current_cycle_number: int
    
    invite_code: Optional[str]
    invite_code_active: bool
    pool_balance: float
    
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True
