import cloudinary
import cloudinary.uploader
from app.core.config import settings
import logging

logger = logging.getLogger(__name__)

# Initialize Cloudinary configuration
cloudinary.config(
    cloud_name=settings.CLOUDINARY_CLOUD_NAME,
    api_key=settings.CLOUDINARY_API_KEY,
    api_secret=settings.CLOUDINARY_API_SECRET,
    secure=True
)

async def upload_image_to_cloudinary(file_bytes: bytes, folder: str = "payajo") -> str:
    """
    Uploads an image (as bytes) to Cloudinary and returns the secure URL.
    This runs synchronously within an async wrapper, so it blocks the thread.
    In a high-throughput scenario, run this in a ThreadPoolExecutor.
    """
    try:
        import asyncio
        loop = asyncio.get_running_loop()
        
        # We run the synchronous upload function in a separate thread so we don't block the asyncio event loop
        def _upload():
            return cloudinary.uploader.upload(
                file_bytes,
                folder=folder,
                resource_type="image"
            )
            
        result = await loop.run_in_executor(None, _upload)
        
        return result.get("secure_url")
    except Exception as e:
        logger.error(f"Cloudinary upload failed: {str(e)}", exc_info=True)
        raise e
