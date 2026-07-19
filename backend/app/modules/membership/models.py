from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.types import String
from datetime import datetime
from app.common.models import Base, UUIDMixin, TimestampMixin

class Membership(Base, UUIDMixin, TimestampMixin):
    __tablename__ = "memberships"

    group_id: Mapped[str] = mapped_column(String, nullable=False, index=True)
    user_id: Mapped[str] = mapped_column(String, nullable=False, index=True)
    
    is_admin: Mapped[bool] = mapped_column(default=False, nullable=False)
    
    auto_debit_enabled: Mapped[bool] = mapped_column(default=False, nullable=False)
    auto_debit_days_before: Mapped[int] = mapped_column(default=1, nullable=False)
    
    kyc_status: Mapped[str] = mapped_column(String(50), nullable=False) # Enum
    status: Mapped[str] = mapped_column(String(50), nullable=False) # Enum

class GroupInvite(Base, UUIDMixin, TimestampMixin):
    __tablename__ = "group_invites"

    group_id: Mapped[str] = mapped_column(String, nullable=False, index=True)
    invited_user_id: Mapped[str] = mapped_column(String, nullable=False, index=True)
    invited_by_user_id: Mapped[str] = mapped_column(String, nullable=False)
    
    status: Mapped[str] = mapped_column(String(50), nullable=False) # Enum
    resolved_at: Mapped[datetime] = mapped_column(nullable=True)
