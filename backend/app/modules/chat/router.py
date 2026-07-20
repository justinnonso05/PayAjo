import logging
from fastapi import APIRouter, Depends, WebSocket, WebSocketDisconnect, Query, UploadFile, File, HTTPException, Form

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import List

from app.core.database import get_db
from app.core.security import get_current_user, verify_access_token_ws
from app.modules.user.models import User
from app.modules.chat.schemas import ChatMessageResponse, ChatMessageCreate
from app.modules.chat.service import get_chat_history_service, verify_membership
from app.modules.chat.models import ChatMessage
from app.core.websocket import manager

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/groups",
    tags=["chat"],
)

@router.get("/{group_id}/chat", response_model=List[ChatMessageResponse])
async def get_chat_history(
    group_id: str,
    limit: int = 50,
    offset: int = 0,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    return await get_chat_history_service(db, group_id, current_user, limit, offset)

from app.services.cloudinary import upload_image_to_cloudinary

@router.post("/{group_id}/chat/image", response_model=ChatMessageResponse)
async def upload_chat_image(
    group_id: str,
    file: UploadFile = File(...),
    message: str = Form(None),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Upload an image to the group chat. Optionally include a text message caption.
    """
    await verify_membership(db, group_id, current_user.id)
    
    if not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="File must be an image")
        
    file_bytes = await file.read()
    url = await upload_image_to_cloudinary(file_bytes, folder=f"payajo/chat/{group_id}")
    
    chat_msg = ChatMessage(
        group_id=group_id,
        sender_id=current_user.id,
        message=message,
        image_url=url,
        is_system=False
    )
    db.add(chat_msg)
    await db.commit()
    await db.refresh(chat_msg)
    
    # Broadcast to all connected websocket clients
    await manager.broadcast(group_id, {
        "action": "new_message",
        "message": {
            "id": str(chat_msg.id),
            "group_id": group_id,
            "sender_id": str(current_user.id),
            "message": message,
            "image_url": url,
            "is_system": False,
            "is_edited": False,
            "is_deleted": False,
            "created_at": chat_msg.created_at.isoformat()
        }
    })
    
    return chat_msg

@router.websocket("/{group_id}/ws")
async def websocket_chat_endpoint(
    websocket: WebSocket,
    group_id: str,
    token: str = Query(...),
    db: AsyncSession = Depends(get_db)
):
    # Authenticate via query param token
    user = await verify_access_token_ws(token, db)
    if not user:
        await websocket.close(code=1008, reason="Invalid or missing token")
        return
        
    try:
        # Verify they are in the group
        await verify_membership(db, group_id, user.id)
    except Exception as e:
        await websocket.close(code=1008, reason="Not a member of this group")
        return

    await manager.connect(websocket, group_id)
    try:
        while True:
            data = await websocket.receive_text()
            # User sent a message
            import json
            try:
                payload = json.loads(data)
                action = payload.get("action", "send")
                
                if action == "send":
                    text = payload.get("message", "").strip()
                    if not text:
                        continue
                    
                    chat_msg = ChatMessage(
                        group_id=group_id,
                        sender_id=user.id,
                        message=text,
                        is_system=False
                    )
                    db.add(chat_msg)
                    await db.commit()
                    await db.refresh(chat_msg)
                    
                    await manager.broadcast(group_id, {
                        "action": "new_message",
                        "message": {
                            "id": str(chat_msg.id),
                            "group_id": group_id,
                            "sender_id": str(user.id),
                            "message": text,
                            "is_system": False,
                            "is_edited": False,
                            "is_deleted": False,
                            "image_url": None,
                            "created_at": chat_msg.created_at.isoformat()
                        }
                    })
                
                elif action == "edit":
                    msg_id = payload.get("message_id")
                    text = payload.get("message", "").strip()
                    if not msg_id or not text:
                        continue
                        
                    result = await db.execute(select(ChatMessage).where(ChatMessage.id == msg_id))
                    chat_msg = result.scalar_one_or_none()
                    
                    if chat_msg and chat_msg.sender_id == user.id and not chat_msg.is_system and not chat_msg.is_deleted:
                        chat_msg.message = text
                        chat_msg.is_edited = True
                        db.add(chat_msg)
                        await db.commit()
                        
                        await manager.broadcast(group_id, {
                            "action": "message_edited",
                            "message": {
                                "id": str(chat_msg.id),
                                "group_id": group_id,
                                "sender_id": str(user.id),
                                "message": text,
                                "is_system": False,
                                "is_edited": True,
                                "is_deleted": False,
                                "image_url": chat_msg.image_url,
                                "created_at": chat_msg.created_at.isoformat()
                            }
                        })
                        
                elif action == "delete":
                    msg_id = payload.get("message_id")
                    if not msg_id:
                        continue
                        
                    result = await db.execute(select(ChatMessage).where(ChatMessage.id == msg_id))
                    chat_msg = result.scalar_one_or_none()
                    
                    if chat_msg and chat_msg.sender_id == user.id and not chat_msg.is_system and not chat_msg.is_deleted:
                        chat_msg.is_deleted = True
                        chat_msg.message = "This message was deleted."
                        db.add(chat_msg)
                        await db.commit()
                        
                        await manager.broadcast(group_id, {
                            "action": "message_deleted",
                            "message_id": str(chat_msg.id)
                        })
                        
            except json.JSONDecodeError:
                # ignore malformed payloads
                pass
                
    except WebSocketDisconnect:
        manager.disconnect(websocket, group_id)
