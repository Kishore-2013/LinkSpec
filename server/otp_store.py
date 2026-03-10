import time
from threading import Lock
import random
from config import Config

class OTPStore:
    def __init__(self):
        # Format: { email: { "code": str, "expiry": float, "attempts": int, "last_sent": float } }
        self._store = {}
        self._lock = Lock()

    def generate_otp(self, email):
        with self._lock:
            now = time.time()
            email = email.lower()
            
            # Rate limiting: Prevent sending too frequently (e.g., 60s)
            if email in self._store:
                if now - self._store[email]["last_sent"] < Config.SEND_COOLDOWN_SECONDS:
                    return None, "Rate limit exceeded. Please wait a minute."

            otp_code = str(random.randint(100000, 999999))
            expiry = now + (Config.OTP_EXPIRY_MINUTES * 60)
            
            self._store[email] = {
                "code": otp_code,
                "expiry": expiry,
                "attempts": 0,
                "last_sent": now
            }
            return otp_code, None

    def verify_otp(self, email, code):
        with self._lock:
            now = time.time()
            email = email.lower()
            
            if email not in self._store:
                return False, "No OTP found for this email."
            
            data = self._store[email]
            
            # Check expiry
            if now > data["expiry"]:
                del self._store[email]
                return False, "OTP has expired."
            
            # Check attempts
            if data["attempts"] >= Config.MAX_VERIFY_ATTEMPTS:
                del self._store[email]
                return False, "Too many failed attempts. Please request a new OTP."
            
            # Verify code
            if data["code"] == code:
                del self._store[email]
                return True, "Verification successful."
            else:
                data["attempts"] += 1
                remaining = Config.MAX_VERIFY_ATTEMPTS - data["attempts"]
                return False, f"Invalid code. {remaining} attempts remaining."

# Singleton instance
otp_manager = OTPStore()
