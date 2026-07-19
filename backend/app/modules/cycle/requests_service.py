import json
from fastapi import HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_
from app.modules.user.models import User
from app.modules.group.models import Group
from app.modules.cycle.models import CycleAssignment, DelegationRequest, SwapRequest
from app.modules.notification.models import Notification
from app.core.security import verify_password
from app.core.pin_limiter import check_pin_rate_limit, record_pin_failure, record_pin_success
from app.modules.chat.service import post_system_message

async def initiate_delegation(db: AsyncSession, group: Group, cycle_number: int, user: User, to_member_id: str, pin: str) -> DelegationRequest:
    try:
        check_pin_rate_limit(user.id)
    except ValueError as e:
        raise HTTPException(status_code=429, detail=str(e))
    if not user.pin_hash or not verify_password(pin, user.pin_hash):
        rem = record_pin_failure(user.id)
        if rem == 0:
            raise HTTPException(status_code=429, detail="Too many incorrect PIN attempts. Try again in 15 minute(s).")
        raise HTTPException(status_code=400, detail=f"Invalid Transaction PIN. {rem} attempt(s) remaining.")
    record_pin_success(user.id)

    # Ensure user is the assigned member for this cycle
    import json
    rotation_order = json.loads(group.rotation_order) if group.rotation_order else []
    
    # We must find the assigned member for `cycle_number`
    # Wait, cycle_number is 1-indexed. The rotation order index is cycle_number - 1 (assuming it doesn't wrap yet).
    # If it wraps, we need a robust way to calculate assigned member.
    assigned_idx = (cycle_number - 1) % len(rotation_order)
    assigned_member_id = rotation_order[assigned_idx]
    
    if assigned_member_id != user.id:
        raise HTTPException(status_code=403, detail="You are not assigned to this cycle")
        
    # Check if cycle is already paid
    assignment_res = await db.execute(select(CycleAssignment).where(and_(CycleAssignment.group_id == group.id, CycleAssignment.cycle_number == cycle_number)))
    assignment = assignment_res.scalar_one_or_none()
    if assignment and assignment.status == "paid":
        raise HTTPException(status_code=400, detail="Cycle already paid")
        
    status = "pending_admin_approval" if group.requires_approval_for_delegate else "auto_approved"
    
    req = DelegationRequest(
        group_id=group.id,
        cycle_number=cycle_number,
        from_member_id=user.id,
        to_member_id=to_member_id,
        status=status
    )
    db.add(req)
    
    if status == "auto_approved":
        if not assignment:
            assignment = CycleAssignment(
                group_id=group.id,
                cycle_number=cycle_number,
                assigned_member_id=assigned_member_id,
                actual_recipient_id=to_member_id,
                delegation_id=req.id,
                status="pending"
            )
            db.add(assignment)
        else:
            assignment.actual_recipient_id = to_member_id
            assignment.delegation_id = req.id
            db.add(assignment)
            
        notif = Notification(user_id=to_member_id, title="Delegation Received", message=f"A payout for cycle {cycle_number} was delegated to you.", type="delegation_approved")
        db.add(notif)
        await post_system_message(db, group.id, f"{user.first_name} delegated their cycle {cycle_number} payout.")
    else:
        admin_notif = Notification(user_id=group.admin_user_id, title="Delegation Request", message=f"User {user.first_name} requested a delegation.", type="delegation_request")
        db.add(admin_notif)
        
    await db.commit()
    await db.refresh(req)
    return req

async def initiate_swap(db: AsyncSession, group: Group, user: User, target_member_id: str, target_cycle_number: int, pin: str) -> SwapRequest:
    try:
        check_pin_rate_limit(user.id)
    except ValueError as e:
        raise HTTPException(status_code=429, detail=str(e))
    if not user.pin_hash or not verify_password(pin, user.pin_hash):
        rem = record_pin_failure(user.id)
        if rem == 0:
            raise HTTPException(status_code=429, detail="Too many incorrect PIN attempts. Try again in 15 minute(s).")
        raise HTTPException(status_code=400, detail=f"Invalid Transaction PIN. {rem} attempt(s) remaining.")
    record_pin_success(user.id)
        
    import json
    rotation_order = json.loads(group.rotation_order) if group.rotation_order else []
    
    # Find user's next cycle
    # For simplicity, we just find the user's FIRST appearance in the rotation order after current_rotation_index
    # or just their primary index.
    initiator_idx = -1
    try:
        initiator_idx = rotation_order.index(user.id)
    except ValueError:
        raise HTTPException(status_code=403, detail="You are not in the rotation order")
        
    initiator_cycle_number = initiator_idx + 1 # simplistic mapping
    
    req = SwapRequest(
        group_id=group.id,
        initiator_member_id=user.id,
        target_member_id=target_member_id,
        initiator_cycle_number=initiator_cycle_number,
        target_cycle_number=target_cycle_number,
        status="pending_counterpart"
    )
    db.add(req)
    
    notif = Notification(
        user_id=target_member_id, 
        title="Swap Request", 
        message=f"{user.first_name} requested a cycle swap with you.", 
        type="swap_request"
    )
    db.add(notif)
    
    await db.commit()
    await db.refresh(req)
    return req

async def respond_swap(db: AsyncSession, group: Group, user: User, swap_id: str, accept: bool, pin: str) -> SwapRequest:
    try:
        check_pin_rate_limit(user.id)
    except ValueError as e:
        raise HTTPException(status_code=429, detail=str(e))
    if not user.pin_hash or not verify_password(pin, user.pin_hash):
        rem = record_pin_failure(user.id)
        if rem == 0:
            raise HTTPException(status_code=429, detail="Too many incorrect PIN attempts. Try again in 15 minute(s).")
        raise HTTPException(status_code=400, detail=f"Invalid Transaction PIN. {rem} attempt(s) remaining.")
    record_pin_success(user.id)
        
    swap_res = await db.execute(select(SwapRequest).where(and_(SwapRequest.id == swap_id, SwapRequest.group_id == group.id)))
    swap = swap_res.scalar_one_or_none()
    
    if not swap or swap.target_member_id != user.id:
        raise HTTPException(status_code=404, detail="Swap request not found or unauthorized")
        
    if swap.status != "pending_counterpart":
        raise HTTPException(status_code=400, detail="Swap request already responded to")
        
    if not accept:
        swap.status = "rejected"
        notif = Notification(user_id=swap.initiator_member_id, title="Swap Rejected", message=f"{user.first_name} rejected your swap request.", type="swap_rejected")
        db.add(notif)
    else:
        swap.status = "pending_admin_approval" if group.requires_approval_for_swap else "accepted"
        
        if swap.status == "accepted":
            # Execute swap
            import json
            rotation_order = json.loads(group.rotation_order) if group.rotation_order else []
            # Exchange indices
            idx1 = swap.initiator_cycle_number - 1
            idx2 = swap.target_cycle_number - 1
            if 0 <= idx1 < len(rotation_order) and 0 <= idx2 < len(rotation_order):
                rotation_order[idx1], rotation_order[idx2] = rotation_order[idx2], rotation_order[idx1]
                group.rotation_order = json.dumps(rotation_order)
                db.add(group)
                
            notif = Notification(user_id=swap.initiator_member_id, title="Swap Accepted", message=f"{user.first_name} accepted your swap request.", type="swap_accepted")
            db.add(notif)
            await post_system_message(db, group.id, f"{user.first_name} and swap initiator swapped their cycles.")
        else:
            admin_notif = Notification(user_id=group.admin_user_id, title="Swap Approval Required", message="A swap request is pending approval.", type="swap_pending_admin")
            db.add(admin_notif)
            
    await db.commit()
    await db.refresh(swap)
    return swap

async def approve_delegation(db: AsyncSession, group: Group, admin_user: User, delegation_id: str, approve: bool, reason: str = None) -> DelegationRequest:
    if group.admin_user_id != admin_user.id:
        raise HTTPException(status_code=403, detail="Only group admin can approve requests")
        
    req_res = await db.execute(select(DelegationRequest).where(and_(DelegationRequest.id == delegation_id, DelegationRequest.group_id == group.id)))
    req = req_res.scalar_one_or_none()
    
    if not req or req.status != "pending_admin_approval":
        raise HTTPException(status_code=404, detail="Request not found or not pending")
        
    if not approve:
        req.status = "rejected"
        msg = "The admin rejected your delegation." + (f" Reason: {reason}" if reason else "")
        notif = Notification(user_id=req.from_member_id, title="Delegation Rejected", message=msg, type="delegation_rejected")
        db.add(notif)
    else:
        req.status = "auto_approved" # We use auto_approved interchangeably here for 'approved'
        
        # Check cycle assignment
        assignment_res = await db.execute(select(CycleAssignment).where(and_(CycleAssignment.group_id == group.id, CycleAssignment.cycle_number == req.cycle_number)))
        assignment = assignment_res.scalar_one_or_none()
        
        if not assignment:
            assignment = CycleAssignment(
                group_id=group.id,
                cycle_number=req.cycle_number,
                assigned_member_id=req.from_member_id,
                actual_recipient_id=req.to_member_id,
                delegation_id=req.id,
                status="pending"
            )
            db.add(assignment)
        else:
            assignment.actual_recipient_id = req.to_member_id
            assignment.delegation_id = req.id
            db.add(assignment)
            
        notif1 = Notification(user_id=req.from_member_id, title="Delegation Approved", message="The admin approved your delegation.", type="delegation_approved")
        notif2 = Notification(user_id=req.to_member_id, title="Delegation Received", message=f"A payout for cycle {req.cycle_number} was delegated to you.", type="delegation_approved")
        db.add(notif1)
        db.add(notif2)
        await post_system_message(db, group.id, f"A delegation was approved for cycle {req.cycle_number}.")
        
    await db.commit()
    await db.refresh(req)
    return req

async def approve_swap(db: AsyncSession, group: Group, admin_user: User, swap_id: str, approve: bool, reason: str = None) -> SwapRequest:
    if group.admin_user_id != admin_user.id:
        raise HTTPException(status_code=403, detail="Only group admin can approve requests")
        
    req_res = await db.execute(select(SwapRequest).where(and_(SwapRequest.id == swap_id, SwapRequest.group_id == group.id)))
    req = req_res.scalar_one_or_none()
    
    if not req or req.status != "pending_admin_approval":
        raise HTTPException(status_code=404, detail="Request not found or not pending")
        
    if not approve:
        req.status = "rejected"
        msg = "The admin rejected the swap." + (f" Reason: {reason}" if reason else "")
        notif1 = Notification(user_id=req.initiator_member_id, title="Swap Rejected", message=msg, type="swap_rejected")
        notif2 = Notification(user_id=req.target_member_id, title="Swap Rejected", message=msg, type="swap_rejected")
        db.add(notif1)
        db.add(notif2)
    else:
        req.status = "accepted"
        import json
        rotation_order = json.loads(group.rotation_order) if group.rotation_order else []
        idx1 = req.initiator_cycle_number - 1
        idx2 = req.target_cycle_number - 1
        if 0 <= idx1 < len(rotation_order) and 0 <= idx2 < len(rotation_order):
            rotation_order[idx1], rotation_order[idx2] = rotation_order[idx2], rotation_order[idx1]
            group.rotation_order = json.dumps(rotation_order)
            db.add(group)
            
        notif1 = Notification(user_id=req.initiator_member_id, title="Swap Approved", message="The admin approved your swap.", type="swap_accepted")
        notif2 = Notification(user_id=req.target_member_id, title="Swap Approved", message="The admin approved the swap.", type="swap_accepted")
        db.add(notif1)
        db.add(notif2)
        await post_system_message(db, group.id, "A cycle swap was approved.")
        
    await db.commit()
    await db.refresh(req)
    return req
