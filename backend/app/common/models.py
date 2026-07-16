import uuid
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column
from sqlalchemy.types import String
from datetime import datetime
from sqlalchemy import func

class Base(DeclarativeBase):
    pass

class TimestampMixin:
    created_at: Mapped[datetime] = mapped_column(default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(default=func.now(), onupdate=func.now(), nullable=False)

class UUIDMixin:
    id: Mapped[str] = mapped_column(
        String, 
        primary_key=True, 
        index=True, 
        default=lambda: str(uuid.uuid4())
    )
