import smtplib
import os
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from abc import ABC, abstractmethod
from azure.communication.email import EmailClient
from dotenv import load_dotenv

load_dotenv()

class EmailProvider(ABC):
    @abstractmethod
    def send_otp(self, recipient_email: str, otp_code: str):
        pass

class GmailProvider(EmailProvider):
    def __init__(self):
        self.user = os.getenv("GMAIL_USER")
        self.password = os.getenv("GMAIL_APP_PASSWORD")
        self.smtp_server = "smtp.gmail.com"
        self.smtp_port = 587

    def send_otp(self, recipient_email: str, otp_code: str):
        msg = MIMEMultipart()
        msg['From'] = self.user
        msg['To'] = recipient_email
        msg['Subject'] = "Your LinkSpec Verification Code"

        body = f"Your verification code is: {otp_code}. It will expire in 5 minutes."
        msg.attach(MIMEText(body, 'plain'))

        with smtplib.SMTP(self.smtp_server, self.smtp_port) as server:
            server.starttls()
            server.login(self.user, self.password)
            server.send_message(msg)

class AzureMS365Provider(EmailProvider):
    def __init__(self):
        self.connection_string = os.getenv("AZURE_CONNECTION_STRING")
        self.sender_address = os.getenv("SENDER_ADDRESS")
        self.client = EmailClient.from_connection_string(self.connection_string)

    def send_otp(self, recipient_email: str, otp_code: str):
        message = {
            "content": {
                "subject": "Your LinkSpec Verification Code",
                "plainText": f"Your verification code is: {otp_code}. It will expire in 5 minutes.",
            },
            "recipients": {
                "to": [{"address": recipient_email}],
            },
            "senderAddress": self.sender_address
        }

        poller = self.client.begin_send(message)
        return poller.result()

def get_email_provider(recipient_email: str):
    email_lower = recipient_email.lower()
    if email_lower.endswith("@gmail.com"):
        print(f"Routing to GmailProvider for {recipient_email}")
        return GmailProvider()
    else:
        print(f"Routing to AzureMS365Provider for {recipient_email}")
        return AzureMS365Provider()
