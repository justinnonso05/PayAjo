import hashlib
import hmac
import logging
from fastapi import Request, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from .models import ProcessedWebhookEvent
from app.modules.user.models import User
from app.modules.group.models import Group
from app.modules.transaction.models import WalletLedgerEntry, GroupLedgerEntry
from app.common.enums import WalletLedgerEntryType, GroupLedgerEntryType
from app.core.config import settings

logger = logging.getLogger(__name__)

async def verify_monnify_signature(request: Request, body_bytes: bytes) -> bool:
    monnify_signature = request.headers.get("monnify-signature")
    if not monnify_signature:
        logger.error("Missing monnify-signature header")
        return False
        
    secret_key = settings.MONNIFY_SECRET_KEY.encode()
    computed_hash = hmac.new(secret_key, body_bytes, hashlib.sha512).hexdigest()
    return hmac.compare_digest(computed_hash, monnify_signature)

async def process_monnify_webhook(payload: dict, db: AsyncSession):
    event_type = payload.get("eventType")
    event_data = payload.get("eventData", {})
    
    if event_type != "SUCCESSFUL_TRANSACTION":
        logger.info(f"Ignoring non-SUCCESSFUL_TRANSACTION event: {event_type}")
        return
        
    monnify_reference = event_data.get("transactionReference")
    if not monnify_reference:
        logger.error(f"Missing transactionReference in webhook payload: {payload}")
        return
        
    # Check idempotency
    existing = await db.execute(select(ProcessedWebhookEvent).where(ProcessedWebhookEvent.monnify_reference == monnify_reference))
    if existing.scalar_one_or_none():
        return # Already processed
        
    amount = float(event_data.get("amountPaid", 0))
    payment_reference = event_data.get("paymentReference", "")
    
    # Path B: Direct to Group
    if payment_reference.startswith("payajo-direct_"):
        # Format: payajo-direct_{group_id}_{cycle_number}_{user_id}_{timestamp}
        parts = payment_reference.split("_")
        if len(parts) >= 5:
            group_id = parts[1]
            cycle_number = int(parts[2])
            user_id = parts[3]
    elif payment_reference.startswith("payajo-direct-"):
        # Legacy Format: payajo-direct-{group_id}-{cycle_number}-{user_id}-{timestamp}
        # Since UUIDs have hyphens, a standard split breaks.
        # UUIDs have 5 parts separated by 4 hyphens.
        parts = payment_reference.split("-")
        if len(parts) >= 14:
            group_id = "-".join(parts[2:7])
            cycle_number = int(parts[7])
            user_id = "-".join(parts[8:13])
        else:
            logger.error(f"Failed to parse legacy direct payment reference: {payment_reference}")
            return
    
    if payment_reference.startswith("payajo-direct_") or payment_reference.startswith("payajo-direct-"):
            
            # Calculate Fees (divide by 100 since configs are in percentages e.g. 1.5, 1)
            monnify_fee = min(amount * (settings.MONNIFY_COLLECTION_FEE_PERCENT / 100), settings.MONNIFY_COLLECTION_FEE_CAP)
            platform_fee = amount * (settings.PAYAJO_PLATFORM_FEE_PERCENT / 100)
            total_fees = monnify_fee + platform_fee
            net_amount = amount - total_fees
            
            # Record platform fee for direct contribution
            fee_entry = WalletLedgerEntry(
                user_id=user_id,
                type=WalletLedgerEntryType.PLATFORM_FEE,
                amount=-total_fees,
                monnify_transaction_reference=f"fee-{monnify_reference}",
                narration="Processing and Platform Fees for Direct Contribution"
            )
            db.add(fee_entry)
            
            # Credit group ledger directly
            entry = GroupLedgerEntry(
                group_id=group_id,
                type=GroupLedgerEntryType.CONTRIBUTION_DIRECT,
                amount=net_amount,
                member_id=user_id,
                cycle_number=cycle_number,
                monnify_transaction_reference=monnify_reference,
                monnify_payment_reference=payment_reference,
                narration=f"Direct contribution for cycle {cycle_number}"
            )
            db.add(entry)
            
            # Update group pool balance
            group_res = await db.execute(select(Group).where(Group.id == group_id))
            group = group_res.scalar_one_or_none()
            if group:
                group.pool_balance = float(group.pool_balance) + net_amount
                db.add(group)
            
            # User and Notification
            user_res = await db.execute(select(User).where(User.id == user_id))
            user = user_res.scalar_one_or_none()
            if user and group:
                from app.modules.notification.models import Notification
                from app.services.email import send_contribution_confirmed_email
                
                notif = Notification(
                    user_id=user.id,
                    title="Contribution Received",
                    message=f"Your direct contribution of ₦{net_amount:,.2f} for cycle {cycle_number} was successful.",
                    type="group_contribution"
                )
                db.add(notif)
                
                import asyncio
                asyncio.create_task(send_contribution_confirmed_email(user.email, user.first_name, amount, group.name, cycle_number))
                
                # Use a separate database session for background tasks to avoid concurrent session usage
                from app.core.database import AsyncSessionLocal
                async def _run_bg_tasks():
                    async with AsyncSessionLocal() as bg_session:
                        from app.modules.group.service import post_system_message
                        await post_system_message(bg_session, group_id, f"{user.first_name} contributed ₦{net_amount:,.2f} for cycle {cycle_number}.")
                        
                        from app.modules.user.risk_service import calculate_user_risk_score
                        await calculate_user_risk_score(user.id, bg_session)
                        
                import asyncio
                asyncio.create_task(_run_bg_tasks())

    
    # Path A: Wallet Top-Up
    else:
        # Top-up is identified by the user's personal reserved account
        dest_info = event_data.get("destinationAccountInformation") or {}
        dest_account_number = dest_info.get("accountNumber")
        if dest_account_number:
            user_res = await db.execute(select(User).where(User.personal_reserved_account_number == dest_account_number))
            user = user_res.scalar_one_or_none()
            if user:
                # Credit wallet full amount
                entry = WalletLedgerEntry(
                    user_id=user.id,
                    type=WalletLedgerEntryType.TOPUP,
                    amount=amount,
                    monnify_transaction_reference=monnify_reference,
                    monnify_payment_reference=payment_reference,
                    narration="Wallet top-up via Monnify"
                )
                db.add(entry)
                
                # Calculate Fees (divide by 100 since configs are in percentages e.g. 1.5, 1)
                monnify_fee = min(amount * (settings.MONNIFY_COLLECTION_FEE_PERCENT / 100), settings.MONNIFY_COLLECTION_FEE_CAP)
                platform_fee = amount * (settings.PAYAJO_PLATFORM_FEE_PERCENT / 100)
                total_fees = monnify_fee + platform_fee
                net_amount = amount - total_fees
                
                # Deduct fees
                fee_entry = WalletLedgerEntry(
                    user_id=user.id,
                    type=WalletLedgerEntryType.PLATFORM_FEE,
                    amount=-total_fees,
                    monnify_transaction_reference=f"fee-{monnify_reference}",
                    narration="Processing and Platform Fees"
                )
                db.add(fee_entry)
                
                # Update user wallet balance with net amount
                user.wallet_balance = float(user.wallet_balance) + net_amount
                db.add(user)
                
                # Notifications
                from app.modules.notification.models import Notification
                from app.services.email import send_wallet_funded_email
                import asyncio
                
                notif = Notification(
                    user_id=user.id,
                    title="Wallet Funded",
                    message=f"Your wallet was topped up with ₦{net_amount:,.2f} (after ₦{total_fees:,.2f} fees).",
                    type="wallet_topup"
                )
                db.add(notif)
                
                asyncio.create_task(send_wallet_funded_email(user.email, user.first_name, net_amount))
        else:
            logger.warning(f"Wallet Top-Up destination account number missing in webhook payload: {payload}")
                
    # Record processed event
    processed = ProcessedWebhookEvent(
        monnify_reference=monnify_reference,
        event_type=event_type
    )
    db.add(processed)
    
    try:
        await db.commit()
        logger.info(f"Successfully processed Monnify webhook for reference {monnify_reference}")
    except Exception as e:
        await db.rollback()
        logger.error(f"Database error while processing webhook {monnify_reference}: {str(e)}", exc_info=True)
        raise
