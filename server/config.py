import os
from dotenv import load_dotenv

load_dotenv()

class Config:
    MS365_TENANT_ID = os.getenv("MS365_TENANT_ID")
    MS365_CLIENT_ID = os.getenv("MS365_CLIENT_ID")
    MS365_CLIENT_SECRET = os.getenv("MS365_CLIENT_SECRET")
    SENDER_EMAIL = os.getenv("SENDER_EMAIL")
    
    OTP_EXPIRY_MINUTES = 5
    MAX_VERIFY_ATTEMPTS = 3
    SEND_COOLDOWN_SECONDS = 60
