from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.types import String
from app.common.models import Base, UUIDMixin, TimestampMixin


class ProcessedWebhookEvent(Base, UUIDMixin, TimestampMixin):
    """
    Stores every processed Monnify webhook event reference.
    Used for idempotency — Monnify retries on any non-200 response,
    so we must never double-credit a contribution or double-fire a payout.
    """
    __tablename__ = "processed_webhook_events"

    # Monnify's unique transaction or payment reference
    monnify_reference: Mapped[str] = mapped_column(String(255), unique=True, nullable=False, index=True)

    # The event type received from Monnify (e.g. SUCCESSFUL_TRANSACTION)
    event_type: Mapped[str] = mapped_column(String(100), nullable=False)
