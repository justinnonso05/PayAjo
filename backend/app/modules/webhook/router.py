from fastapi import APIRouter, Request
from app.common.schemas import BaseResponse
from .schemas import WebhookPayload

router = APIRouter(prefix="/webhooks", tags=["Webhooks"])

@router.post("/monnify", response_model=BaseResponse[str])
async def handle_monnify_webhook(payload: WebhookPayload, request: Request):
    # TODO: Verify Monnify signature and process event
    return BaseResponse(
        success=True,
        message="Webhook processed successfully",
        data="OK"
    )
