import requests
import msal
from config import Config

class EmailService:
    def __init__(self):
        self.authority = f"https://login.microsoftonline.com/{Config.MS365_TENANT_ID}"
        self.scope = ["https://graph.microsoft.com/.default"]
        self.client_app = msal.ConfidentialClientApplication(
            Config.MS365_CLIENT_ID,
            authority=self.authority,
            client_credential=Config.MS365_CLIENT_SECRET,
        )

    def _get_access_token(self):
        result = self.client_app.acquire_token_for_client(scopes=self.scope)
        if "access_token" in result:
            return result["access_token"]
        else:
            raise Exception(f"Failed to acquire token: {result.get('error_description')}")

    def send_otp_email(self, recipient_email, otp_code):
        access_token = self._get_access_token()
        url = f"https://graph.microsoft.com/v1.0/users/{Config.SENDER_EMAIL}/sendMail"
        
        headers = {
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json"
        }
        
        email_content = f"""Hello,

Your verification code is: {otp_code}

This code will expire in {Config.OTP_EXPIRY_MINUTES} minutes.

If you did not request this code, please ignore this email.

Regards,
ApplyWizz Team
{Config.SENDER_EMAIL}"""

        payload = {
            "message": {
                "subject": "ApplyWizz Verification Code",
                "body": {
                    "contentType": "Text",
                    "content": email_content
                },
                "toRecipients": [
                    {
                        "emailAddress": {
                            "address": recipient_email
                        }
                    }
                ]
            }
        }
        
        response = requests.post(url, headers=headers, json=payload)
        if response.status_code != 202:
            raise Exception(f"Failed to send email: {response.text}")
        return True

# Singleton instance
email_service = EmailService()
