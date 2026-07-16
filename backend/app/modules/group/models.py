from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.types import String, Integer, Float
from app.common.models import Base, UUIDMixin, TimestampMixin

class Group(Base, UUIDMixin, TimestampMixin):
    __tablename__ = "groups"

    name: Mapped[str] = mapped_column(String(255), nullable=False)
    admin_user_id: Mapped[str] = mapped_column(String, nullable=False, index=True)
    
    contribution_amount: Mapped[float] = mapped_column(Float, nullable=False)
    cycle_length_days: Mapped[int] = mapped_column(Integer, nullable=False)
    payout_day_offset: Mapped[int] = mapped_column(Integer, nullable=False)
    
    quorum_percent: Mapped[int] = mapped_column(Integer, nullable=False)
    shortfall_policy: Mapped[str] = mapped_column(String(50), nullable=False) # Enum as string
    
    rotation_order: Mapped[str] = mapped_column(String, nullable=True) # JSON serialized list
    
    current_rotation_index: Mapped[int] = mapped_column(Integer, default=0)
    current_cycle_number: Mapped[int] = mapped_column(Integer, default=1)
    
    status: Mapped[str] = mapped_column(String(50), nullable=False) # Enum as string
