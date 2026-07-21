from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import model_validator

class Settings(BaseSettings):
    PROJECT_NAME: str = "PayAjo Backend"
    
    # Other settings
    GEMINI_API_KEY: str = ""
    
    # Database
    DATABASE_URL: str = "postgresql+asyncpg://postgres:password@localhost/payajo"
    
    # Security
    SECRET_KEY: str = "super-secret-key-change-me"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 10080 # 7 days
    
    # Monnify
    MONNIFY_API_KEY: str = "mock-api-key"
    MONNIFY_SECRET_KEY: str = "mock-secret-key"
    MONNIFY_BASE_URL: str = "https://sandbox.monnify.com"
    MONNIFY_CONTRACT_CODE: str = "mock-contract-code"
    # The merchant's Monnify settlement account number (source for disbursements)
    MONNIFY_WALLET_ACCOUNT: str = ""
    # Bank code to use when creating reserved accounts (e.g. "232" for Sterling)
    MONNIFY_DEFAULT_PREFERRED_BANK: str = ""

    # Scheduler Config
    SCHEDULER_INTERVAL_MINUTES: int = 5

    # Email — Brevo (Sendinblue)
    BREVO_API_KEY: str = ""
    EMAIL_FROM_ADDRESS: str = "noreply@justinch.dev"
    EMAIL_FROM_NAME: str = "PayAjo"
    EMAIL_DOMAIN: str = "justinch.dev"  # Base domain for email sending

    # OTP settings
    OTP_EXPIRE_MINUTES: int = 10  # OTPs expire after 10 minutes
    
    # AI Integration
    GEMINI_API_KEY: str = ""

    # Cloudinary Integration
    CLOUDINARY_CLOUD_NAME: str = ""
    CLOUDINARY_API_KEY: str = ""
    CLOUDINARY_API_SECRET: str = ""

    # Fee Configuration
    MONNIFY_COLLECTION_FEE_PERCENT: float = 1.5 # 1.5%
    MONNIFY_COLLECTION_FEE_CAP: float = 2000.0
    
    MONNIFY_PAYOUT_FEE_TIER_1: float = 10.0 # < 10,000
    MONNIFY_PAYOUT_FEE_TIER_2: float = 20.0 # >= 10,000
    MONNIFY_PAYOUT_FEE_TIER_3: float = 40.0 # >= 50,000
    
    PAYAJO_PLATFORM_FEE_PERCENT: float = 1.0 # 1%
    MAX_TOTAL_FEE_CAP: float = 2500.0 # Total fees (Monnify + Platform) will never exceed this

    model_config = SettingsConfigDict(env_file=".env", case_sensitive=True, extra="ignore")

    @model_validator(mode='after')
    def override_db_driver(self) -> 'Settings':
        if self.DATABASE_URL.startswith("postgres://"):
            self.DATABASE_URL = self.DATABASE_URL.replace("postgres://", "postgresql+asyncpg://", 1)
        elif self.DATABASE_URL.startswith("postgresql://") and not self.DATABASE_URL.startswith("postgresql+asyncpg://"):
            self.DATABASE_URL = self.DATABASE_URL.replace("postgresql://", "postgresql+asyncpg://", 1)
            
        # asyncpg does not support sslmode=require, replace it with ssl=require
        if "sslmode=" in self.DATABASE_URL:
            self.DATABASE_URL = self.DATABASE_URL.replace("sslmode=", "ssl=")
        # asyncpg does not support channel_binding
        if "&channel_binding=require" in self.DATABASE_URL:
            self.DATABASE_URL = self.DATABASE_URL.replace("&channel_binding=require", "")
        if "?channel_binding=require&" in self.DATABASE_URL:
            self.DATABASE_URL = self.DATABASE_URL.replace("?channel_binding=require&", "?")
            
        return self

settings = Settings()
