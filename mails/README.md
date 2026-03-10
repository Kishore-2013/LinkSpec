# LinkSpec OTP Service (Python)

A secure FastAPI-based OTP verification service supporting multiple email providers.

## Features
- **Dual Provider Support**: Use Gmail (SMTP) or Microsoft 365 (Azure Communication Services).
- **Security**: 5-minute OTP expiry and 3-attempt limit per OTP.
- **Async Execution**: Emails are sent in the background to keep API responses fast.

## Setup

1. **Install Dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

2. **Configuration**:
   Copy `.env.example` to `.env` and fill in your credentials.
   ```bash
   cp .env.example .env
   ```

3. **Run the Server**:
   ```bash
   uvicorn main:app --reload
   ```

## API Endpoints

### 1. Send OTP
**POST** `/send-otp`
```json
{
  "email": "user@example.com"
}
```

### 2. Verify OTP
**POST** `/verify-otp`
```json
{
  "email": "user@example.com",
  "otp_code": "123456"
}
```

## Running with Gmail
Set `EMAIL_PROVIDER=gmail` and provide `GMAIL_USER` and `GMAIL_APP_PASSWORD`.

## Running with MS 365
Set `EMAIL_PROVIDER=azure` and provide `AZURE_CONNECTION_STRING` and `SENDER_ADDRESS` (support@applywizz.com).
