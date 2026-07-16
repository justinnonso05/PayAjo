from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.types import String
from app.common.models import Base, UUIDMixin, TimestampMixin

class Membership(Base, UUIDMixin, TimestampMixin):
    __tablename__ = "memberships"

    group_id: Mapped[str] = mapped_column(String, nullable=False, index=True)
    user_id: Mapped[str] = mapped_column(String, nullable=False, index=True)
    
    is_admin: Mapped[bool] = mapped_column(default=False, nullable=False)
    
    kyc_status: Mapped[str] = mapped_column(String(50), nullable=False) # Enum
    status: Mapped[str] = mapped_column(String(50), nullable=False) # Enum
    
    risk_score: Mapped[str] = mapped_column(String, nullable=True) # JSON serialized dict
