from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError
from app.core.config import settings
from app.common.schemas import BaseResponse
from contextlib import asynccontextmanager
from app.core.scheduler import start_scheduler, stop_scheduler

import asyncio
from app.core import events

@asynccontextmanager
async def lifespan(app: FastAPI):
    events.global_loop = asyncio.get_running_loop()
    start_scheduler()
    yield
    stop_scheduler()

app = FastAPI(
    title=settings.PROJECT_NAME,
    openapi_url="/openapi.json",
    docs_url="/docs",
    redoc_url="/redoc",
    swagger_ui_parameters={"persistAuthorization": True},
    lifespan=lifespan
)

from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    # In production, we'd log the full traceback here
    return JSONResponse(
        status_code=500,
        content=BaseResponse(
            success=False,
            message="An unexpected error occurred. Please try again later.",
            data=None
        ).model_dump()
    )

@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    errors = exc.errors()
    error_msgs = []
    for err in errors:
        loc_parts = [str(l) for l in err["loc"] if str(l) not in ("body", "query", "path")]
        field_name = loc_parts[-1] if loc_parts else "Field"
        
        msg = err["msg"]
        if msg.startswith("Value error, "):
            error_msgs.append(msg[len("Value error, "):])
        elif msg == "Field required":
            error_msgs.append(f"{field_name.replace('_', ' ').capitalize()} is required.")
        else:
            error_msgs.append(f"{field_name}: {msg}")
            
    final_message = error_msgs[0] if len(error_msgs) == 1 else "; ".join(error_msgs)
    
    return JSONResponse(
        status_code=422,
        content=BaseResponse(
            success=False,
            message=final_message,
            data=None
        ).model_dump()
    )

@app.get("/health", response_model=BaseResponse[str])
async def health_check():
    return BaseResponse(
        success=True,
        message="PayAjo Backend is running",
        data="OK"
    )

from app.modules.user.router import router as user_router
from app.modules.group.router import router as group_router
from app.modules.membership.router import router as membership_router
from app.modules.auth.router import router as auth_router
from app.modules.webhook.router import router as webhook_router
from app.modules.cycle.router import router as cycle_router
from app.modules.notification.router import router as notification_router
from app.modules.chat.router import router as chat_router

app.include_router(user_router, prefix="/api/v1")
app.include_router(group_router, prefix="/api/v1")
app.include_router(membership_router, prefix="/api/v1")
app.include_router(auth_router, prefix="/api/v1")
app.include_router(webhook_router, prefix="/api/v1")
app.include_router(cycle_router, prefix="/api/v1")
app.include_router(notification_router, prefix="/api/v1")
app.include_router(chat_router, prefix="/api/v1")
