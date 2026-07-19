from pydantic import BaseModel
from typing import Optional
from datetime import datetime, time
from app.common.enums import ShortfallPolicy, GroupStatus, CycleFrequency

class GroupBase(BaseModel):
    name: str
    contribution_amount: float
    
    cycle_frequency: CycleFrequency
    payout_day_of_week: Optional[int] = None
    payout_day_of_month: Optional[int] = None
    payout_month: Optional[int] = None
    
    requires_approval_for_delegate: bool = True
    requires_approval_for_swap: bool = True
    member_cap: Optional[int] = None
    
    payout_time: Optional[time] = None

class GroupCreate(GroupBase):
    pass

class GroupUpdate(BaseModel):
    name: Optional[str] = None
    contribution_amount: Optional[float] = None
    cycle_frequency: Optional[CycleFrequency] = None
    payout_day_of_week: Optional[int] = None
    payout_day_of_month: Optional[int] = None
    payout_month: Optional[int] = None
    requires_approval_for_delegate: Optional[bool] = None
    requires_approval_for_swap: Optional[bool] = None
    member_cap: Optional[int] = None
    
    payout_time: Optional[time] = None

class GroupStartRequest(BaseModel):
    randomize: bool = False
    manual_order: Optional[list[str]] = None

class JoinGroupRequest(BaseModel):
    invite_code: str

class PayFromWalletRequest(BaseModel):
    pin: str

class AutoDebitSetupRequest(BaseModel):
    enabled: bool
    days_before: int
    pin: str

class GroupInviteCreate(BaseModel):
    email_or_username: str

class GroupInviteResponse(BaseModel):
    id: str
    group_id: str
    invited_user_id: str
    invited_by_user_id: str
    status: str
    resolved_at: Optional[datetime]
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True

class MembershipResponse(BaseModel):
    id: str
    group_id: str
    user_id: str
    is_admin: bool
    kyc_status: str
    status: str
    risk_score: int
    risk_factors: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True

class GroupMemberProfileResponse(BaseModel):
    id: str
    group_id: str
    user_id: str
    is_admin: bool
    status: str
    joined_at: datetime
    # User info
    first_name: str
    last_name: str
    username: str
    risk_score: int
    risk_factors: Optional[str] = None
    # Payment status for current cycle
    has_paid_current_cycle: bool = False
    payout_position: Optional[int] = None
    
    # Auto-debit settings
    auto_debit_enabled: bool = False
    auto_debit_days_before: int = 1

    class Config:
        from_attributes = True

class GroupRotationResponse(BaseModel):
    cycle_number: int
    user_id: str
    first_name: str
    last_name: str
    username: str
    payout_date: Optional[datetime] = None
    is_completed: bool
    is_current: bool

    class Config:
        from_attributes = True

class GroupResponse(GroupBase):
    id: str
    admin_user_id: str
    invite_code: Optional[str] = None
    invite_code_active: bool
    pool_balance: float
    current_rotation_index: int
    current_cycle_number: int
    status: str
    quorum_percent: int
    started_at: Optional[datetime] = None
    next_payout_date: Optional[datetime] = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True
