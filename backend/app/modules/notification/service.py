import asyncio
from sqlalchemy import event, select
from app.modules.notification.models import Notification
from app.modules.user.models import User
from app.services.push import send_push_notification
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.database import AsyncSessionLocal
import logging

logger = logging.getLogger(__name__)

async def _send_notification_push_async(user_id: str, title: str, message: str, n_type: str, action_id: str):
    logger.info(f"Evaluating push notification for user {user_id} ({n_type})...")
    try:
        async with AsyncSessionLocal() as session:
            result = await session.execute(select(User.fcm_token).where(User.id == user_id))
            fcm_token = result.scalar_one_or_none()
            
        if fcm_token:
            logger.info(f"FCM token found for user {user_id}. Dispatching push...")
            data = {"type": n_type}
            if action_id: 
                data["action_id"] = str(action_id)
            await send_push_notification(fcm_token, title, message, data)
        else:
            logger.info(f"User {user_id} has no FCM token registered. Push skipped.")
    except Exception as e:
        logger.error(f"Error resolving FCM token for user {user_id}: {e}")

async def create_and_dispatch_notification(db: AsyncSession, user_id: str, title: str, message: str, type: str, action_id: str = None) -> Notification:
    """
    Creates a notification in the database and explicitly dispatches a background task
    to send the Firebase push notification on the main asyncio event loop.
    """
    notif = Notification(
        user_id=user_id,
        title=title,
        message=message,
        type=type,
        action_id=action_id
    )
    db.add(notif)
    # Note: The caller is still responsible for calling db.commit()!
    
    # Schedule the push notification explicitly
    try:
        loop = asyncio.get_running_loop()
        logger.info(f"Explicitly scheduling push notification for user {user_id} (type: {type})")
        loop.create_task(_send_notification_push_async(user_id, title, message, type, action_id))
    except RuntimeError:
        logger.error("No running event loop found to schedule push notification.")
        
    return notif
