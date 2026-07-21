import logging
import asyncio
from datetime import datetime, timezone
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_

from app.modules.group.models import Group
from app.modules.membership.models import Membership
from app.modules.user.models import User
from app.modules.transaction.models import GroupLedgerEntry, WalletLedgerEntry
from app.common.enums import GroupLedgerEntryType, WalletLedgerEntryType, MembershipStatus, GroupStatus
from app.modules.chat.service import post_system_message
from app.modules.notification.models import Notification
from app.services.email import send_contribution_confirmed_email

logger = logging.getLogger(__name__)

async def evaluate_and_process_auto_debits(db: AsyncSession, group: Group):
    """
    Checks active members in the group who have auto-debit enabled.
    If today is within their 'auto_debit_days_before' threshold of next_payout_date,
    and they haven't paid yet, attempts to deduct from wallet.
    """
    if group.status != GroupStatus.ACTIVE or not group.next_payout_date:
        return

    now_utc = datetime.now(timezone.utc)
    
    # We only process if there is an upcoming payout in the future
    # If the payout is already due, they missed the auto-debit window or it fired right before.
    # We can be generous and say if next_payout_date >= now_utc
    days_to_payout = (group.next_payout_date - now_utc).days

    # We want members whose days_to_payout <= auto_debit_days_before
    # and they have auto_debit_enabled == True
    mem_res = await db.execute(
        select(Membership).where(
            and_(
                Membership.group_id == group.id,
                Membership.status == MembershipStatus.ACTIVE,
                Membership.auto_debit_enabled == True
            )
        )
    )
    memberships = mem_res.scalars().all()

    for mem in memberships:
        if days_to_payout > mem.auto_debit_days_before:
            continue # Not yet time for this user

        # 1. Check if user already paid for this cycle
        entry_res = await db.execute(
            select(GroupLedgerEntry).where(
                and_(
                    GroupLedgerEntry.group_id == group.id,
                    GroupLedgerEntry.member_id == mem.user_id,
                    GroupLedgerEntry.cycle_number == group.current_cycle_number,
                    GroupLedgerEntry.type == GroupLedgerEntryType.CONTRIBUTION_WALLET # Or any contribution
                )
            )
        )
        existing_contribution = entry_res.scalar_one_or_none()
        if existing_contribution:
            continue # Already paid
            
        # 2. Check wallet balance
        user_res = await db.execute(select(User).where(User.id == mem.user_id))
        user = user_res.scalar_one_or_none()
        if not user:
            continue
            
        if float(user.wallet_balance) < group.contribution_amount:
            # Insufficient funds. We skip. They will be marked as short.
            logger.info(f"Auto-debit skipped for user {user.id} in group {group.id}: Insufficient balance")
            continue
            
        # 3. Perform internal ledger transfer
        try:
            amount = group.contribution_amount
            
            # Debit wallet
            wallet_entry = WalletLedgerEntry(
                user_id=user.id,
                type=WalletLedgerEntryType.PAY_GROUP,
                amount=-amount,
                related_group_id=group.id,
                narration=f"Auto-Debit for {group.name} Cycle {group.current_cycle_number}"
            )
            db.add(wallet_entry)
            
            # Update wallet balance
            user.wallet_balance = float(user.wallet_balance) - amount
            db.add(user)
            
            # Credit group pool
            group_entry = GroupLedgerEntry(
                group_id=group.id,
                type=GroupLedgerEntryType.CONTRIBUTION_WALLET,
                amount=amount,
                member_id=user.id,
                cycle_number=group.current_cycle_number,
                narration="Auto-Debit Contribution"
            )
            db.add(group_entry)
            
            # Update pool balance
            group.pool_balance = float(group.pool_balance) + amount
            db.add(group)
            
            from app.modules.notification.service import create_and_dispatch_notification
            await create_and_dispatch_notification(
                db=db,
                user_id=user.id,
                title="Contribution Received (Auto-Debit)",
                message=f"Your auto-debit contribution of ₦{amount:,.2f} for cycle {group.current_cycle_number} was successful.",
                type="group_contribution"
            )
            
            # Chat message
            await post_system_message(db, group.id, f"{user.first_name} automatically contributed ₦{amount:,.2f} for cycle {group.current_cycle_number} via Auto-Debit!")
            
            await db.commit()
            
            # Send Email
            asyncio.create_task(
                send_contribution_confirmed_email(
                    to_email=user.email,
                    to_name=user.first_name,
                    amount=amount,
                    group_name=group.name,
                    cycle=group.current_cycle_number
                )
            )
            logger.info(f"Auto-debit successful for user {user.id} in group {group.id}")
            
        except Exception as e:
            await db.rollback()
            logger.error(f"Error during auto-debit for user {user.id} in group {group.id}: {e}", exc_info=True)
