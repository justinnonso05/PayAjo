from datetime import datetime, timezone, timedelta
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, func
from app.modules.group.models import Group, ReminderTracking
from app.modules.membership.models import Membership
from app.modules.user.models import User
from app.modules.transaction.models import GroupLedgerEntry
from app.common.enums import GroupStatus, GroupLedgerEntryType, MembershipStatus
from app.services.ai import generate_reminder_copy
from app.services.email import send_email
from app.modules.notification.service import create_and_dispatch_notification
from app.modules.chat.models import ChatMessage
import logging

logger = logging.getLogger(__name__)

async def evaluate_and_send_reminders(db: AsyncSession, group: Group):
    """
    Evaluates a group to see if any members need reminders based on the frequency logic.
    Sends AI-crafted reminders to the chat, DB notifications, and emails.
    """
    if not group.next_payout_date or group.status != GroupStatus.ACTIVE:
        return
        
    now = datetime.now(timezone.utc)
    
    # next_payout_date has a date, but we also want to consider payout_time if available
    # Actually, next_payout_date might already have the time component.
    # Let's just use next_payout_date directly for calculations
    payout_date = group.next_payout_date.replace(tzinfo=timezone.utc)
    
    # Only calculate if the payout is in the future
    if payout_date < now:
        return
        
    time_until = payout_date - now
    days_until = time_until.days
    
    # Determine if today is a day we should send a reminder
    should_remind = False
    reminder_type = ""
    
    if group.cycle_frequency == "weekly":
        # from T-2 days to payout time, every day
        if 0 <= days_until <= 2:
            should_remind = True
            reminder_type = "daily"
            
    elif group.cycle_frequency == "monthly":
        # from T-7 days to payout time, every day
        if 0 <= days_until <= 7:
            should_remind = True
            reminder_type = "daily"
            
    elif group.cycle_frequency == "yearly":
        # Two months to payout, twice the first month, once every week for the last month, every day for the last week
        if 30 < days_until <= 60:
            should_remind = True
            reminder_type = "biweekly"
        elif 7 < days_until <= 30:
            should_remind = True
            reminder_type = "weekly"
        elif 0 <= days_until <= 7:
            should_remind = True
            reminder_type = "daily"
            
    if not should_remind:
        return
        
    # Get all active members
    mem_res = await db.execute(
        select(Membership, User)
        .join(User, Membership.user_id == User.id)
        .where(
            Membership.group_id == group.id,
            Membership.status == MembershipStatus.ACTIVE
        )
    )
    members = mem_res.all()
    
    for membership, user in members:
        # Check if they have already paid for the current cycle
        payment_res = await db.execute(
            select(GroupLedgerEntry).where(
                GroupLedgerEntry.group_id == group.id,
                GroupLedgerEntry.member_id == user.id,
                GroupLedgerEntry.cycle_number == group.current_cycle_number,
                GroupLedgerEntry.type.in_([
                    GroupLedgerEntryType.CONTRIBUTION_WALLET.value, 
                    GroupLedgerEntryType.CONTRIBUTION_DIRECT.value
                ])
            )
        )
        if payment_res.scalar_one_or_none():
            continue # Already paid
            
        # Check if we already sent THIS type of reminder recently
        # To prevent spam, if reminder_type is "daily", we shouldn't send it if we sent one in the last 20 hours
        # If "weekly", not within the last 6 days
        # If "biweekly", not within the last 13 days
        tracking_res = await db.execute(
            select(ReminderTracking).where(
                ReminderTracking.group_id == group.id,
                ReminderTracking.user_id == user.id,
                ReminderTracking.cycle_number == group.current_cycle_number,
                ReminderTracking.reminder_type == reminder_type
            )
        )
        tracking = tracking_res.scalar_one_or_none()
        
        if tracking:
            time_since_last = now - tracking.last_sent_at.replace(tzinfo=timezone.utc)
            
            if reminder_type == "daily" and time_since_last.total_seconds() < 20 * 3600:
                continue
            if reminder_type == "weekly" and time_since_last.days < 6:
                continue
            if reminder_type == "biweekly" and time_since_last.days < 13:
                continue
                
            # Update tracking
            tracking.last_sent_at = now
            db.add(tracking)
        else:
            # Create tracking
            tracking = ReminderTracking(
                group_id=group.id,
                user_id=user.id,
                cycle_number=group.current_cycle_number,
                reminder_type=reminder_type,
                last_sent_at=now
            )
            db.add(tracking)
            
            # Send Reminder!
            await send_manual_reminder(user, group, db)

async def send_manual_reminder(user: User, group: Group, db: AsyncSession) -> str:
    """
    Forces a reminder to be sent (AI generation, chat message, notification, and email)
    and returns the generated message copy.
    """
    now = datetime.now(timezone.utc)
    try:
        # 1. Generate AI Copy
        ai_message = await generate_reminder_copy(
            member_name=user.first_name,
            group_name=group.name,
            amount=float(group.contribution_amount),
            cycle_number=group.current_cycle_number
        )
        
        # 2. Chat System Message
        chat_msg = ChatMessage(
            group_id=group.id,
            sender_id=group.admin_user_id,
            message=ai_message,
            is_system=True
        )
        db.add(chat_msg)
        await db.flush()
        
        # 3. Notification
        await create_and_dispatch_notification(db=db, user_id=user.id,
            title="Ajo Contribution Reminder",
            message=ai_message,
            type="payment_reminder")
        
        # 4. Email
        await send_email(
            user.email,
            user.first_name,
            f"PayAjo Reminder: {group.name}",
            f"<p>{ai_message}</p>"
        )
        
        # 5. Broadcast to WebSocket (if connected)
        from app.modules.chat.router import manager
        await manager.broadcast(group.id, {
            "action": "new_message",
            "message": {
                "id": str(chat_msg.id),
                "group_id": group.id,
                "sender_id": str(chat_msg.sender_id),
                "message": ai_message,
                "is_system": True,
                "is_edited": False,
                "is_deleted": False,
                "created_at": now.isoformat()
            }
        })
        
        logger.info(f"Manually sent reminder to {user.first_name} for group {group.name}")
        return ai_message
    except Exception as e:
        logger.error(f"Error sending manual reminder to user {user.id} in group {group.id}: {e}", exc_info=True)
        raise
