from pydantic import BaseModel
from typing import Optional, Any
from datetime import datetime
from app.common.enums import MembershipStatus, KYCStatus

class MembershipBase(BaseModel):
    group_id: str
    user_id: str

class MembershipCreate(MembershipBase):
    pass

class MembershipResponse(MembershipBase):
    id: str
    reserved_account_number: Optional[str] = None
    reserved_account_bank: Optional[str] = None
    kyc_status: KYCStatus
    status: MembershipStatus
    risk_score: Optional[Any] = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True
