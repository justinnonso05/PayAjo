from pydantic import BaseModel
from typing import Optional
from datetime import datetime
from app.common.enums import ShortfallPolicy, GroupStatus

class GroupBase(BaseModel):
    name: str
    contribution_amount: float
    cycle_length_days: int
    payout_day_offset: int
    quorum_percent: int
    shortfall_policy: ShortfallPolicy

class GroupCreate(GroupBase):
    pass

class GroupResponse(GroupBase):
    id: str
    admin_user_id: str
    status: GroupStatus
    current_rotation_index: int
    current_cycle_number: int
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True
