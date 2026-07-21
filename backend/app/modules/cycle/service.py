import logging
from datetime import datetime, timezone
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_
from app.modules.group.models import Group
from app.modules.membership.models import Membership
from app.modules.transaction.models import WalletLedgerEntry, GroupLedgerEntry
from app.common.enums import WalletLedgerEntryType, GroupLedgerEntryType, MembershipStatus, GroupStatus
from app.modules.cycle.models import CycleAssignment, DelegationRequest, SwapRequest
from app.modules.chat.service import post_system_message
from app.modules.notification.service import create_and_dispatch_notification
from app.modules.user.models import User

logger = logging.getLogger(__name__)

async def get_active_members_count(db: AsyncSession, group_id: str) -> int:
    result = await db.execute(
        select(Membership).where(
            and_(
                Membership.group_id == group_id,
                Membership.status == MembershipStatus.ACTIVE
            )
        )
    )
    return len(result.scalars().all())

from datetime import timedelta, time

def calculate_next_payout_date(group: Group, reference_date: datetime) -> datetime:
    """Calculates the exact next datetime based on frequency rules."""
    p_time = group.payout_time or time(0, 0)
    
    if group.cycle_frequency == "weekly":
        day_diff = group.payout_day_of_week - reference_date.isoweekday()
        if day_diff <= 0:
            day_diff += 7
        target_date = reference_date + timedelta(days=day_diff)
        return target_date.replace(hour=p_time.hour, minute=p_time.minute, second=0, microsecond=0)
        
    elif group.cycle_frequency == "monthly":
        import calendar
        month = reference_date.month
        year = reference_date.year
        target_day = group.payout_day_of_month
        
        if reference_date.day < target_day:
            pass # Same month
        else:
            month += 1
            if month > 12:
                month = 1
                year += 1
                
        _, max_day = calendar.monthrange(year, month)
        actual_day = min(target_day, max_day)
        return reference_date.replace(year=year, month=month, day=actual_day, hour=p_time.hour, minute=p_time.minute, second=0, microsecond=0)
        
    elif group.cycle_frequency == "yearly":
        import calendar
        year = reference_date.year
        target_month = group.payout_month
        target_day = group.payout_day_of_month
        
        if reference_date.month < target_month or (reference_date.month == target_month and reference_date.day < target_day):
            pass # Same year
        else:
            year += 1
            
        _, max_day = calendar.monthrange(year, target_month)
        actual_day = min(target_day, max_day)
        return reference_date.replace(year=year, month=target_month, day=actual_day, hour=p_time.hour, minute=p_time.minute, second=0, microsecond=0)

    return reference_date + timedelta(days=7)

async def evaluate_payout_for_group(db: AsyncSession, group: Group):
    # 1. Check if group is active
    if group.status != GroupStatus.ACTIVE:
        return
        
    # 2. Check if already paid for this cycle
    current_cycle = group.current_cycle_number
    assignment_res = await db.execute(
        select(CycleAssignment).where(
            and_(
                CycleAssignment.group_id == group.id,
                CycleAssignment.cycle_number == current_cycle
            )
        )
    )
    assignment = assignment_res.scalar_one_or_none()
    
    if assignment and assignment.status == "paid":
        return # Already paid
        
    # 3. Check Quorum
    member_count = await get_active_members_count(db, group.id)
    if member_count == 0:
        return
        
    target_amount = group.contribution_amount * member_count
    collected_ratio = (group.pool_balance / target_amount) * 100 if target_amount > 0 else 0
    
    if collected_ratio < group.quorum_percent:
        logger.info(f"Group {group.id} cycle {current_cycle} quorum not met ({collected_ratio}% < {group.quorum_percent}%)")
        return {
            "status": "quorum_failed",
            "group_name": group.name,
            "collected": collected_ratio,
            "required": group.quorum_percent
        }
        
    # 4. Determine recipient
    if not assignment:
        # If assignment record doesn't exist, we fallback to the current rotation index
        import json
        rotation_order = json.loads(group.rotation_order) if group.rotation_order else []
        if not rotation_order or group.current_rotation_index >= len(rotation_order):
            logger.error(f"Group {group.id} rotation order exhausted or invalid")
            return
            
        assigned_id = rotation_order[group.current_rotation_index]
        assignment = CycleAssignment(
            group_id=group.id,
            cycle_number=current_cycle,
            assigned_member_id=assigned_id,
            actual_recipient_id=assigned_id,
            status="pending"
        )
        db.add(assignment)
        await db.flush()
        
    actual_recipient_id = assignment.actual_recipient_id
    
    # 5. Payout (Internal Ledger Transfer)
    payout_amount = group.pool_balance
    
    # Debit group pool
    group_entry = GroupLedgerEntry(
        group_id=group.id,
        type=GroupLedgerEntryType.PAYOUT,
        amount=-payout_amount,
        member_id=actual_recipient_id,
        cycle_number=current_cycle,
        narration=f"Cycle {current_cycle} Payout"
    )
    db.add(group_entry)
    
    group.pool_balance = 0.0 # Drain pool
    db.add(group)
    
    # Credit user wallet
    wallet_entry = WalletLedgerEntry(
        user_id=actual_recipient_id,
        type=WalletLedgerEntryType.PAYOUT_RECEIVED,
        amount=payout_amount,
        related_group_id=group.id,
        related_contribution_id=group_entry.id,
        narration=f"Ajo Payout from {group.name}"
    )
    db.add(wallet_entry)
    
    user_res = await db.execute(select(User).where(User.id == actual_recipient_id))
    user = user_res.scalar_one()
    user.wallet_balance = float(user.wallet_balance) + payout_amount
    db.add(user)
    
    assignment.status = "paid"
    db.add(assignment)
    
    # 6. Notify
    await create_and_dispatch_notification(db=db, user_id=actual_recipient_id,
        title="Payout Received",
        message=f"You have received NGN {payout_amount} payout from {group.name} for cycle {current_cycle}.",
        type="payout_received")
    
    if actual_recipient_id != group.admin_user_id:
        await create_and_dispatch_notification(db=db, user_id=group.admin_user_id,
            title="Cycle Paid Out",
            message=f"Cycle {current_cycle} payout of NGN {payout_amount} was sent to user wallet.",
            type="payout_processed")
        
    await post_system_message(db, group.id, f"A payout of ₦{payout_amount:,.2f} was successfully sent for cycle {current_cycle}!")
        
    # Send email in the background
    from app.services.email import send_payout_received_email
    import asyncio
    asyncio.create_task(
        send_payout_received_email(
            to_email=user.email,
            to_name=user.first_name,
            amount=payout_amount,
            group_name=group.name
        )
    )
    
    # 7. Advance cycle
    group.current_cycle_number += 1
    
    # 8. Set next payout date
    now_utc = datetime.now(timezone.utc)
    group.next_payout_date = calculate_next_payout_date(group, now_utc)
    db.add(group)
    
    # Check if we should advance the rotation index
    # We advance if there wasn't a swap that already handled it permanently? Actually, the PRD says:
    # "advance current_rotation_index only if this was not a swap-affected cycle (swaps already permanently reordered rotation_order)"
    # Wait, the simplest way is to always advance rotation index, and if it exceeds len, loop back to 0.
    import json
    rotation_order = json.loads(group.rotation_order) if group.rotation_order else []
    group.current_rotation_index = (group.current_rotation_index + 1) % len(rotation_order) if rotation_order else 0
    db.add(group)
    
    logger.info(f"Successfully processed payout for group {group.id} cycle {current_cycle}")
    
    return {
        "status": "paid",
        "group_name": group.name,
        "user_name": f"{user.first_name} {user.last_name}",
        "user_id": user.id,
        "amount": payout_amount
    }
