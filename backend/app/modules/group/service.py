import random
import string
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from fastapi import HTTPException, status

from app.modules.user.models import User
from app.modules.group.models import Group
from app.modules.membership.models import Membership, GroupInvite
from app.modules.group.schemas import GroupCreate, GroupUpdate, GroupStartRequest
from app.common.enums import GroupStatus, MembershipStatus, KYCStatus, GroupInviteStatus, WalletLedgerEntryType, GroupLedgerEntryType
from app.modules.transaction.models import WalletLedgerEntry, GroupLedgerEntry
from app.modules.notification.models import Notification
from app.core.pin_limiter import check_pin_rate_limit, record_pin_failure, record_pin_success
import uuid

from datetime import datetime, timezone
from app.services.email import send_group_invite_email, send_group_join_approved_email
from app.modules.chat.service import post_system_message

def generate_invite_code(length: int = 6) -> str:
    """Generate a random alphanumeric invite code."""
    return ''.join(random.choices(string.ascii_uppercase + string.digits, k=length))

async def create_group_service(user: User, data: GroupCreate, db: AsyncSession) -> Group:
    """
    Creates a new Group and automatically adds the creator as an active Admin.
    """
    # 1. Create the Group
    new_group = Group(
        name=data.name,
        admin_user_id=user.id,
        contribution_amount=data.contribution_amount,
        cycle_frequency=data.cycle_frequency,
        payout_day_of_week=data.payout_day_of_week,
        payout_day_of_month=data.payout_day_of_month,
        payout_month=data.payout_month,
        payout_time=data.payout_time,
        quorum_percent=100,
        requires_approval_for_delegate=data.requires_approval_for_delegate,
        requires_approval_for_swap=data.requires_approval_for_swap,
        invite_code=generate_invite_code(),
        invite_code_active=True,
        pool_balance=0.00,
        member_cap=data.member_cap,
        current_cycle_number=0,
        status=GroupStatus.GATHERING
    )
    db.add(new_group)
    
    # flush to get the new_group.id
    await db.flush()

    # 2. Add the Admin Membership
    admin_membership = Membership(
        group_id=new_group.id,
        user_id=user.id,
        is_admin=True,
        kyc_status=KYCStatus.MOCKED_VERIFIED if user.kyc_status else KYCStatus.PENDING,
        status=MembershipStatus.ACTIVE
    )
    db.add(admin_membership)

    await db.commit()
    await db.refresh(new_group)

    return new_group

async def update_group_service(admin_user: User, group_id: str, data: GroupUpdate, db: AsyncSession) -> Group:
    await _verify_admin(admin_user.id, group_id, db)
    
    result = await db.execute(select(Group).where(Group.id == group_id))
    group = result.scalar_one_or_none()
    if not group:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Group not found")
        
    update_data = data.model_dump(exclude_unset=True)
    
    # If the group is already ACTIVE, block changing financial/cadence details
    if group.status != GroupStatus.GATHERING:
        forbidden_fields = {'contribution_amount', 'cycle_frequency', 'payout_day_of_week', 'payout_day_of_month', 'payout_month', 'payout_time'}
        for field in forbidden_fields:
            if field in update_data:
                new_val = update_data[field]
                old_val = getattr(group, field)
                # If value hasn't actually changed, just ignore it rather than throwing an error
                if str(new_val) != str(old_val):
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail=f"Cannot modify {field} after the group has started."
                    )
                # Pop it so we don't accidentally write it anyway
                update_data.pop(field)
            
    for key, value in update_data.items():
        setattr(group, key, value)
        
    db.add(group)
    await db.commit()
    await db.refresh(group)
    return group

async def start_group_service(admin_user: User, group_id: str, data: GroupStartRequest, db: AsyncSession) -> Group:
    import json
    await _verify_admin(admin_user.id, group_id, db)
    
    result = await db.execute(select(Group).where(Group.id == group_id))
    group = result.scalar_one_or_none()
    if not group:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Group not found")
        
    if group.status != GroupStatus.GATHERING:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Group is already started or completed")
        
    # Get all active members
    mem_result = await db.execute(select(Membership.user_id).where(Membership.group_id == group_id, Membership.status == MembershipStatus.ACTIVE))
    active_member_ids = mem_result.scalars().all()
    
    if len(active_member_ids) < 2:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Need at least 2 members to start rotation")
        
    # Generate rotation order
    if data.manual_order:
        # Validate that all provided ids are active members and there are no duplicates/omissions
        if set(data.manual_order) != set(active_member_ids):
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Manual order must include exactly all active members")
        order = data.manual_order
    elif data.randomize:
        order = list(active_member_ids)
        random.shuffle(order)
    else:
        # Default to join order (which is how they are returned by default query, or we can sort by joined_at, but we'll just use the fetched list)
        order = list(active_member_ids)
        
    group.rotation_order = json.dumps(order)
    group.status = GroupStatus.ACTIVE
    group.started_at = datetime.now(timezone.utc).replace(tzinfo=None)
    group.current_cycle_number = 1
    group.current_rotation_index = 0
    
    from app.modules.cycle.service import calculate_next_payout_date
    now_utc = datetime.now(timezone.utc)
    group.next_payout_date = calculate_next_payout_date(group, now_utc)
    
    db.add(group)
    await db.commit()
    await db.refresh(group)
    await post_system_message(db, group_id, "The group rotation has started. Cycle 1 begins now!")
    return group

async def join_group_service(user: User, invite_code: str, db: AsyncSession) -> Group:
    """
    Allows a user to join a group using an invite code.
    """
    # 0. Check KYC
    if not user.kyc_status:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You must complete KYC before joining a group"
        )

    # 1. Find group by invite code
    result = await db.execute(
        select(Group).where(
            Group.invite_code == invite_code,
            Group.invite_code_active == True # noqa: E712
        )
    )
    group = result.scalar_one_or_none()
    
    if not group:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Invalid or inactive invite code"
        )
        
    # 2. Check if already a member
    membership_result = await db.execute(
        select(Membership).where(
            Membership.group_id == group.id,
            Membership.user_id == user.id
        )
    )
    if membership_result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You are already a member of this group"
        )
        
    # 3. Check member cap
    if group.member_cap:
        count_result = await db.execute(
            select(func.count()).where(
                Membership.group_id == group.id,
                Membership.status == MembershipStatus.ACTIVE
            )
        )
        current_members = count_result.scalar() or 0
        if current_members >= group.member_cap:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="This group has reached its maximum member capacity"
            )
            
    # 4. Create membership
    new_membership = Membership(
        group_id=group.id,
        user_id=user.id,
        is_admin=False,
        kyc_status=KYCStatus.MOCKED_VERIFIED if user.kyc_status else KYCStatus.PENDING,
        status=MembershipStatus.PENDING_APPROVAL
    )
    db.add(new_membership)
    await db.commit()
    
    return group

async def _verify_admin(user_id: str, group_id: str, db: AsyncSession):
    """Helper to check if a user is admin of a group."""
    result = await db.execute(
        select(Membership).where(
            Membership.group_id == group_id,
            Membership.user_id == user_id,
            Membership.is_admin == True,
            Membership.status == MembershipStatus.ACTIVE
        )
    )
    if not result.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only group admins can perform this action")

async def approve_join_request_service(admin_user: User, group_id: str, member_user_id: str, approve: bool, db: AsyncSession):
    await _verify_admin(admin_user.id, group_id, db)
    
    result = await db.execute(
        select(Membership).where(
            Membership.group_id == group_id,
            Membership.user_id == member_user_id,
            Membership.status == MembershipStatus.PENDING_APPROVAL
        )
    )
    membership = result.scalar_one_or_none()
    if not membership:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Pending membership not found")
        
    if approve:
        membership.status = MembershipStatus.ACTIVE
        # Fetch user to send email
        user_result = await db.execute(select(User).where(User.id == member_user_id))
        member_user = user_result.scalar_one()
        group_result = await db.execute(select(Group).where(Group.id == group_id))
        group = group_result.scalar_one()
        
        await send_group_join_approved_email(member_user.email, member_user.first_name, group.name)
        await post_system_message(db, group_id, f"{member_user.first_name} joined the group.")
    else:
        membership.status = MembershipStatus.REMOVED
        
    db.add(membership)
    await db.commit()

async def send_targeted_invite_service(admin_user: User, group_id: str, email_or_username: str, db: AsyncSession):
    await _verify_admin(admin_user.id, group_id, db)
    
    group_result = await db.execute(select(Group).where(Group.id == group_id))
    group = group_result.scalar_one()
    
    user_result = await db.execute(
        select(User).where((User.email == email_or_username) | (User.username == email_or_username))
    )
    target_user = user_result.scalar_one_or_none()
    if not target_user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
        
    # Check if already a member or pending
    mem_result = await db.execute(
        select(Membership).where(Membership.group_id == group_id, Membership.user_id == target_user.id)
    )
    if mem_result.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="User is already a member or has a pending request")
        
    # Create invite
    db_invite_res = await db.execute(select(GroupInvite).where(GroupInvite.group_id == group_id, GroupInvite.invited_user_id == target_user.id))
    db_invite = db_invite_res.scalar_one_or_none()
    
    invite = GroupInvite(
        group_id=group_id,
        invited_user_id=target_user.id,
        invited_by_user_id=admin_user.id,
        status=GroupInviteStatus.PENDING
    )
    db.add(invite)
    if db_invite:
        db.delete(db_invite)
    
    notif = Notification(user_id=target_user.id, title="Group Invite", message=f"You have been invited to join {group.name}.", type="group_invite")
    db.add(notif)
    
    await db.commit()
    await db.refresh(invite)
    
    await send_group_invite_email(target_user.email, target_user.first_name, group.name, f"{admin_user.first_name} {admin_user.last_name}")
    return invite

async def pay_group_from_wallet_service(user: User, group_id: str, pin: str, db: AsyncSession):
    import bcrypt

    # 1. Rate-limit check
    try:
        check_pin_rate_limit(user.id)
    except ValueError as e:
        raise HTTPException(status_code=429, detail=str(e))

    # 2. Verify PIN
    if not user.pin_hash:
        raise HTTPException(status_code=400, detail="Transaction PIN not set")
    if not bcrypt.checkpw(pin.encode(), user.pin_hash.encode()):
        rem = record_pin_failure(user.id)
        if rem == 0:
            raise HTTPException(status_code=429, detail="Too many incorrect PIN attempts. Try again in 15 minute(s).")
        raise HTTPException(status_code=401, detail=f"Invalid Transaction PIN. {rem} attempt(s) remaining.")
    record_pin_success(user.id)
        
    # 2. Get Group
    group_res = await db.execute(select(Group).where(Group.id == group_id))
    group = group_res.scalar_one_or_none()
    if not group:
        raise HTTPException(status_code=404, detail="Group not found")
        
    if group.status != GroupStatus.ACTIVE:
        raise HTTPException(status_code=400, detail="Group is not active")
        
    if not group.started_at:
        raise HTTPException(status_code=400, detail="Group has not started yet. Contributions are locked.")
        
    # 3. Check membership
    mem_res = await db.execute(select(Membership).where(Membership.user_id == user.id, Membership.group_id == group_id))
    membership = mem_res.scalar_one_or_none()
    if not membership or membership.status != MembershipStatus.ACTIVE:
        raise HTTPException(status_code=403, detail="You are not an active member of this group")
        
    # 4. Check Wallet Balance
    amount = group.contribution_amount
    if user.wallet_balance < amount:
        raise HTTPException(status_code=400, detail="Insufficient wallet balance")
        
    # 4.5 Check for duplicate payment in this cycle
    existing_payment_res = await db.execute(
        select(GroupLedgerEntry).where(
            GroupLedgerEntry.group_id == group_id,
            GroupLedgerEntry.member_id == user.id,
            GroupLedgerEntry.cycle_number == group.current_cycle_number
        )
    )
    if existing_payment_res.scalar_one_or_none():
        raise HTTPException(status_code=400, detail=f"You have already contributed for cycle {group.current_cycle_number}")
        
    # 5. Execute Ledger Transfer
    # Deduct from User
    user.wallet_balance = float(user.wallet_balance) - float(amount)
    db.add(user)
    
    # Add to Group
    group.pool_balance = float(group.pool_balance) + float(amount)
    db.add(group)
    
    # Ledger Entries
    group_ledger = GroupLedgerEntry(
        group_id=group.id,
        type=GroupLedgerEntryType.CONTRIBUTION_WALLET,
        amount=amount,
        member_id=user.id,
        cycle_number=group.current_cycle_number,
        narration=f"Contribution from wallet for cycle {group.current_cycle_number}"
    )
    db.add(group_ledger)
    await db.flush() # To get ID if needed
    
    wallet_ledger = WalletLedgerEntry(
        user_id=user.id,
        type=WalletLedgerEntryType.PAY_GROUP,
        amount=-amount, # Debit
        related_group_id=group.id,
        related_contribution_id=group_ledger.id,
        narration=f"Paid contribution to group {group.name}"
    )
    db.add(wallet_ledger)
    
    await db.commit()
    await db.refresh(group)
    
    # Notifications and Messages
    from app.modules.notification.models import Notification
    from app.services.email import send_contribution_confirmed_email
    import asyncio
    
    notif = Notification(
        user_id=user.id,
        title="Contribution Received",
        message=f"Your contribution of ₦{amount:,.2f} for cycle {group.current_cycle_number} was successful.",
        type="group_contribution"
    )
    db.add(notif)
    await db.commit()
    
    await post_system_message(db, group_id, f"{user.first_name} contributed ₦{amount:,.2f} for cycle {group.current_cycle_number}.")
    
    asyncio.create_task(send_contribution_confirmed_email(user.email, user.first_name, amount, group.name, group.current_cycle_number))
    
    # Recalculate risk score asynchronously
    from app.modules.user.risk_service import calculate_user_risk_score
    asyncio.create_task(calculate_user_risk_score(user.id, db))
    
    return group

async def generate_direct_payment_service(user: User, group_id: str, db: AsyncSession):
    # 1. Get Group
    group_res = await db.execute(select(Group).where(Group.id == group_id))
    group = group_res.scalar_one_or_none()
    if not group:
        raise HTTPException(status_code=404, detail="Group not found")
        
    if group.status != GroupStatus.ACTIVE:
        raise HTTPException(status_code=400, detail="Group is not active")
        
    if not group.started_at:
        raise HTTPException(status_code=400, detail="Group has not started yet. Contributions are locked.")
        
    # 2. Check membership
    mem_res = await db.execute(select(Membership).where(Membership.user_id == user.id, Membership.group_id == group_id))
    membership = mem_res.scalar_one_or_none()
    if not membership or membership.status != MembershipStatus.ACTIVE:
        raise HTTPException(status_code=403, detail="You are not an active member of this group")
        
    # 3. Check for duplicate payment in this cycle
    existing_payment_res = await db.execute(
        select(GroupLedgerEntry).where(
            GroupLedgerEntry.group_id == group_id,
            GroupLedgerEntry.member_id == user.id,
            GroupLedgerEntry.cycle_number == group.current_cycle_number
        )
    )
    if existing_payment_res.scalar_one_or_none():
        raise HTTPException(status_code=400, detail=f"You have already contributed for cycle {group.current_cycle_number}")
        
    import time
    from app.services.monnify import monnify_client
    
    # Format required by webhook: ajopay-direct_{group_id}_{cycle_number}_{user_id}_{timestamp}
    ref = f"ajopay-direct_{group.id}_{group.current_cycle_number}_{user.id}_{int(time.time())}"
    
    # 4. Call Monnify Step 1: Initialize Transaction
    try:
        init_res = await monnify_client.initialize_transaction(
            amount=group.contribution_amount,
            customer_name=f"{user.first_name} {user.last_name}",
            customer_email=user.email,
            payment_reference=ref,
            payment_description=f"AjoPay contribution - Group {group.name} cycle {group.current_cycle_number}"
        )
        transaction_ref = init_res.get("transactionReference")
        checkout_url = init_res.get("checkoutUrl")
        
        # 5. Call Monnify Step 2: Get Dynamic Account
        dva_res = await monnify_client.init_bank_transfer(transaction_ref)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to communicate with Monnify: {str(e)}")

    # Return real details to the frontend
    return {
        "paymentReference": ref,
        "transactionReference": transaction_ref,
        "checkoutUrl": checkout_url,
        "amount": group.contribution_amount,
        "accountNumber": dva_res.get("accountNumber"),
        "bankName": dva_res.get("bankName"),
        "bankCode": dva_res.get("bankCode"),
        "accountName": dva_res.get("accountName"),
        "expiresOn": dva_res.get("expiresOn"),
        "accountDurationSeconds": dva_res.get("accountDurationSeconds")
    }

async def get_group_members_service(group_id: str, db: AsyncSession):
    # Get group to know current cycle number and rotation order
    group_res = await db.execute(select(Group).where(Group.id == group_id))
    group = group_res.scalar_one_or_none()
    if not group:
        raise HTTPException(status_code=404, detail="Group not found")

    # Parse rotation order for position lookup
    import json
    rotation_order = []
    if group.rotation_order:
        try:
            rotation_order = json.loads(group.rotation_order)
        except Exception:
            pass

    # Get all members
    stmt = select(Membership, User).join(User, Membership.user_id == User.id).where(Membership.group_id == group_id)
    result = await db.execute(stmt)

    # Pre-fetch all paid member ids for the current cycle (if group started)
    paid_member_ids = set()
    if group.current_cycle_number > 0:
        paid_res = await db.execute(
            select(GroupLedgerEntry.member_id).where(
                GroupLedgerEntry.group_id == group_id,
                GroupLedgerEntry.cycle_number == group.current_cycle_number,
                GroupLedgerEntry.type.in_([
                    GroupLedgerEntryType.CONTRIBUTION_WALLET.value,
                    GroupLedgerEntryType.CONTRIBUTION_DIRECT.value,
                ])
            )
        )
        paid_member_ids = {row[0] for row in paid_res.all()}

    members = []
    for mem, usr in result.all():
        # Which position in the rotation is this user?
        payout_position = None
        if usr.user_id in rotation_order if hasattr(usr, 'user_id') else False:
            payout_position = rotation_order.index(usr.id) + 1
        elif usr.id in rotation_order:
            payout_position = rotation_order.index(usr.id) + 1

        members.append({
            "id": mem.id,
            "group_id": mem.group_id,
            "user_id": mem.user_id,
            "is_admin": mem.is_admin,
            "status": mem.status,
            "joined_at": mem.created_at,
            "first_name": usr.first_name,
            "last_name": usr.last_name,
            "username": usr.username,
            "risk_score": usr.risk_score,
            "risk_factors": usr.risk_factors,
            "has_paid_current_cycle": usr.id in paid_member_ids,
            "payout_position": payout_position,
        })
    return members


async def get_group_rotation_service(group_id: str, db: AsyncSession) -> list:
    """Return the full payout rotation schedule for a group."""
    import json

    group_res = await db.execute(select(Group).where(Group.id == group_id))
    group = group_res.scalar_one_or_none()
    if not group:
        raise HTTPException(status_code=404, detail="Group not found")

    if not group.rotation_order:
        return []  # Group hasn't started yet

    rotation_order = json.loads(group.rotation_order)

    # Get all users in the rotation in one query
    users_res = await db.execute(select(User).where(User.id.in_(rotation_order)))
    users_by_id = {u.id: u for u in users_res.scalars().all()}

    # Get next payout date base
    from app.modules.cycle.service import calculate_next_payout_date
    from datetime import timedelta

    result = []
    for idx, user_id in enumerate(rotation_order):
        usr = users_by_id.get(user_id)
        if not usr:
            continue
        cycle_num = idx + 1
        is_completed = cycle_num < group.current_cycle_number
        is_current = cycle_num == group.current_cycle_number

        result.append({
            "cycle_number": cycle_num,
            "user_id": user_id,
            "first_name": usr.first_name,
            "last_name": usr.last_name,
            "username": usr.username,
            "payout_date": group.next_payout_date if is_current else None,
            "is_completed": is_completed,
            "is_current": is_current,
        })

    return result


async def respond_to_invite_service(user: User, invite_id: str, accept: bool, db: AsyncSession):
    result = await db.execute(
        select(GroupInvite).where(GroupInvite.id == invite_id, GroupInvite.invited_user_id == user.id, GroupInvite.status == GroupInviteStatus.PENDING)
    )
    invite = result.scalar_one_or_none()
    if not invite:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Invite not found or already processed")
        
    if accept:
        if not user.kyc_status:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You must complete KYC before accepting a group invite"
            )
            
        invite.status = GroupInviteStatus.ACCEPTED
        # Since admin invited them, they bypass approval
        new_membership = Membership(
            group_id=invite.group_id,
            user_id=user.id,
            is_admin=False,
            kyc_status=KYCStatus.MOCKED_VERIFIED if user.kyc_status else KYCStatus.PENDING,
            status=MembershipStatus.ACTIVE
        )
        db.add(new_membership)
        await post_system_message(db, invite.group_id, f"{user.first_name} joined the group.")
    else:
        invite.status = GroupInviteStatus.REJECTED
        
    invite.resolved_at = datetime.now(timezone.utc).replace(tzinfo=None)
    db.add(invite)
    await db.commit()
    return invite

async def rotate_invite_code_service(admin_user: User, group_id: str, db: AsyncSession):
    await _verify_admin(admin_user.id, group_id, db)
    
    result = await db.execute(select(Group).where(Group.id == group_id))
    group = result.scalar_one()
    
    group.invite_code = generate_invite_code()
    db.add(group)
    await db.commit()
    await db.refresh(group)
    return group

async def setup_auto_debit_service(user: User, group_id: str, enabled: bool, days_before: int, pin: str, db: AsyncSession):
    import bcrypt
    from app.core.pin_limiter import check_pin_rate_limit, record_pin_failure, record_pin_success

    # 1. Rate-limit check
    try:
        check_pin_rate_limit(user.id)
    except ValueError as e:
        raise HTTPException(status_code=429, detail=str(e))

    # 2. Verify PIN
    if not user.pin_hash:
        raise HTTPException(status_code=400, detail="Transaction PIN not set")
    if not bcrypt.checkpw(pin.encode(), user.pin_hash.encode()):
        rem = record_pin_failure(user.id)
        if rem == 0:
            raise HTTPException(status_code=429, detail="Too many incorrect PIN attempts. Try again in 15 minute(s).")
        raise HTTPException(status_code=401, detail=f"Invalid Transaction PIN. {rem} attempt(s) remaining.")
    record_pin_success(user.id)

    # 3. Find Membership
    mem_res = await db.execute(
        select(Membership).where(
            Membership.group_id == group_id, Membership.user_id == user.id
        )
    )
    membership = mem_res.scalar_one_or_none()
    if not membership:
        raise HTTPException(status_code=404, detail="You are not a member of this group")

    # 4. Update
    if days_before < 0:
        raise HTTPException(status_code=400, detail="Days before must be >= 0")

    membership.auto_debit_enabled = enabled
    membership.auto_debit_days_before = days_before
    db.add(membership)
    await db.commit()

    return {
        "id": membership.id,
        "group_id": membership.group_id,
        "user_id": membership.user_id,
        "is_admin": membership.is_admin,
        "status": membership.status,
        "joined_at": membership.created_at,
        "first_name": user.first_name,
        "last_name": user.last_name,
        "username": user.username,
        "risk_score": user.risk_score,
        "risk_factors": user.risk_factors,
        "has_paid_current_cycle": False,
        "auto_debit_enabled": membership.auto_debit_enabled,
        "auto_debit_days_before": membership.auto_debit_days_before
    }
