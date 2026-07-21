from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, and_
from app.core.database import get_db
from app.core.security import get_current_user
from app.modules.user.models import User
from app.common.schemas import BaseResponse
from app.modules.notification.models import Notification
from .schemas import NotificationResponse, MarkReadRequest
import app.modules.notification.service  # This registers the event listener

router = APIRouter(prefix="/notifications", tags=["Notifications"])

@router.get("", response_model=BaseResponse[list[NotificationResponse]])
async def get_notifications(
    unread_only: bool = False,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    stmt = select(Notification).where(Notification.user_id == current_user.id).order_by(Notification.created_at.desc())
    if unread_only:
        stmt = stmt.where(Notification.is_read == False)
        
    res = await db.execute(stmt)
    notifications = res.scalars().all()
    
    return BaseResponse(success=True, message="Notifications fetched", data=notifications)

@router.post("/mark-read", response_model=BaseResponse[str])
async def mark_notifications_read(
    data: MarkReadRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    if data.notification_ids:
        stmt = update(Notification).where(
            and_(
                Notification.user_id == current_user.id,
                Notification.id.in_(data.notification_ids)
            )
        ).values(is_read=True)
    else:
        stmt = update(Notification).where(
            Notification.user_id == current_user.id
        ).values(is_read=True)
        
    await db.execute(stmt)
    await db.commit()
    
    return BaseResponse(success=True, message="Notifications marked as read", data="OK")
