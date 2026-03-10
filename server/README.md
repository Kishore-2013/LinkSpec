# ApplyWizz OTP Service (Flask)

A Python/Flask backend that sends OTP verification emails via Microsoft Graph API.

## Features
- **MS Graph Integration**: Sends emails from `support@applywizz.com` using Azure App credentials.
- **Secure Memory Storage**: Thread-safe OTP management.
- **Safety Measures**: 5-minute expiry, 3-attempt limit, and 1-minute send cooldown.

## Setup

1. **Navigate to the server directory**:
   ```bash
   cd server
   ```

2. **Install dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

3. **Configure Environment**:
   The `.env` file should already be populated with your Azure credentials.

4. **Run the Server**:
   ```bash
   python app.py
   ```

## API Testing (PowerShell)

### 1. Send OTP
```powershell
Invoke-RestMethod -Uri http://localhost:5000/send-otp -Method Post -ContentType "application/json" -Body '{"email":"your-email@example.com"}'
```

### 2. Verify OTP
```powershell
Invoke-RestMethod -Uri http://localhost:5000/verify-otp -Method Post -ContentType "application/json" -Body '{"email":"your-email@example.com", "otp_code":"123456"}'
```
