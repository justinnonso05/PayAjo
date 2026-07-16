from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError
from app.core.config import settings
from app.common.schemas import BaseResponse

app = FastAPI(
    title=settings.PROJECT_NAME,
    openapi_url="/openapi.json",
    docs_url="/docs",
    redoc_url="/redoc",
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
        loc = ".".join([str(l) for l in err["loc"]])
        msg = err["msg"]
        error_msgs.append(f"{loc}: {msg}")
    
    return JSONResponse(
        status_code=422,
        content=BaseResponse(
            success=False,
            message=f"Validation error: {'; '.join(error_msgs)}",
            data=None
        ).model_dump()
    )

@app.get("/health", response_model=BaseResponse[str])
async def health_check():
    return BaseResponse(
        success=True,
        message="AjoPay Backend is running",
        data="OK"
    )

from app.modules.user.router import router as user_router
from app.modules.group.router import router as group_router
from app.modules.membership.router import router as membership_router
from app.modules.auth.router import router as auth_router
from app.modules.webhook.router import router as webhook_router

app.include_router(user_router, prefix="/api/v1")
app.include_router(group_router, prefix="/api/v1")
app.include_router(membership_router, prefix="/api/v1")
app.include_router(auth_router, prefix="/api/v1")
app.include_router(webhook_router, prefix="/api/v1")
