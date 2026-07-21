import firebase_admin
from firebase_admin import credentials, messaging
import os
import logging

logger = logging.getLogger(__name__)

# Initialize Firebase app only once
_firebase_initialized = False

def init_firebase():
    global _firebase_initialized
    if _firebase_initialized:
        return

    import json

    # 1. Check for Environment Variable first (Production)
    env_creds = os.environ.get("FIREBASE_CREDENTIALS_JSON")
    if env_creds:
        try:
            cred_dict = json.loads(env_creds)
            cred = credentials.Certificate(cred_dict)
            firebase_admin.initialize_app(cred)
            _firebase_initialized = True
            logger.info("Firebase Admin SDK initialized from environment variable.")
            return
        except Exception as e:
            logger.error(f"Failed to initialize Firebase from env var: {e}")

    # 2. Fallback to Local File System
    base_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    cred_path = os.path.join(base_dir, "firebase-adminsdk.json")
    
    if os.path.exists(cred_path):
        try:
            cred = credentials.Certificate(cred_path)
            firebase_admin.initialize_app(cred)
            _firebase_initialized = True
            logger.info("Firebase Admin SDK initialized from local file.")
        except Exception as e:
            logger.error(f"Failed to initialize Firebase Admin SDK from file: {e}")
    else:
        logger.warning("Firebase credentials not found. Push notifications will run in mock mode.")


init_firebase()


async def send_push_notification(fcm_token: str, title: str, body: str, data: dict = None):
    """
    Sends a push notification to the given FCM token.
    If firebase is not initialized, it logs the notification instead (mock mode).
    This function is intended to be run in a background task (e.g. asyncio.create_task).
    """
    if not fcm_token:
        return

    if not _firebase_initialized:
        logger.info(f"[MOCK PUSH] To: {fcm_token} | Title: {title} | Body: {body} | Data: {data}")
        return

    try:
        # We use asyncio.to_thread because firebase-admin messaging is synchronous
        import asyncio
        
        # Make sure data only contains string values as required by FCM
        str_data = {}
        if data:
            for k, v in data.items():
                str_data[k] = str(v) if v is not None else ""

        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data=str_data,
            token=fcm_token,
        )
        
        response = await asyncio.to_thread(messaging.send, message)
        logger.info(f"Successfully sent message: {response}")
    except Exception as e:
        logger.error(f"Error sending push notification to {fcm_token}: {e}")
