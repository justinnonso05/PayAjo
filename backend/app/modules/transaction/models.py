from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.types import String, Numeric
from sqlalchemy import ForeignKey
from app.common.models import Base, UUIDMixin, TimestampMixin


class Transaction(Base, UUIDMixin, TimestampMixin):
    __tablename__ = "transactions"

    user_id: Mapped[str] = mapped_column(String, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    amount: Mapped[float] = mapped_column(Numeric(precision=18, scale=2), nullable=False)

    # Type: wallet_funding | group_contribution | payout | withdrawal
    type: Mapped[str] = mapped_column(String(50), nullable=False)

    # Status: pending | completed | failed
    status: Mapped[str] = mapped_column(String(50), nullable=False)

    # Optional group reference (null for wallet top-ups and withdrawals)
    group_id: Mapped[str] = mapped_column(String, ForeignKey("groups.id", ondelete="SET NULL"), nullable=True, index=True)

    # Unique reference for idempotency (Monnify ref or internal UUID)
    reference: Mapped[str] = mapped_column(String(255), unique=True, nullable=False, index=True)

    # Human-readable description
    narration: Mapped[str] = mapped_column(String(500), nullable=True)
