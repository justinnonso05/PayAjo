from pydantic import BaseModel
from typing import Any

class WebhookPayload(BaseModel):
    # Simplified payload structure for Monnify Webhooks
    eventType: str
    eventData: Any
