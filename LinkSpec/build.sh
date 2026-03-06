#!/bin/bash
set -e

# 1. Setup Flutter SDK
echo "--- Ensuring Flutter SDK is present ---"
if [ ! -d "flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable --depth 1
fi

# Use absolute path for the build session to avoid "command not found"
export FLUTTER_HOME="$(pwd)/flutter"
export PATH="$FLUTTER_HOME/bin:$PATH"

# 2. Configuration
flutter config --no-analytics
flutter precache --web

# 3. Environment Check
flutter doctor -v

# 4. Build
echo "--- Starting Flutter Web Build ---"
flutter pub get

# 4. Perform Release Build
# Updated for Flutter 3.41+ (web-renderer is handled automatically)
echo "--- Building Flutter Web (Release) ---"
flutter build web --release \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY \
  --dart-define=API_BASE_URL=$API_BASE_URL \
  --dart-define=GMAIL_SENDER_EMAIL=$GMAIL_SENDER_EMAIL \
  --dart-define=GMAIL_APP_PASSWORD=$GMAIL_APP_PASSWORD \
  --dart-define=SUPABASE_PROFILE_BUCKET=$SUPABASE_PROFILE_BUCKET \
  --dart-define=SUPABASE_POST_BUCKET=$SUPABASE_POST_BUCKET \
  --dart-define=GMAIL_OTP_ROUTE=$GMAIL_OTP_ROUTE \
  --dart-define=MICROSOFT_OTP_ROUTE=$MICROSOFT_OTP_ROUTE \
  --dart-define=API_SECRET_KEY=$API_SECRET_KEY \
  --dart-define=MS365_TENANT_ID=$MS365_TENANT_ID \
  --dart-define=MS365_CLIENT_ID=$MS365_CLIENT_ID \
  --dart-define=MS365_CLIENT_SECRET=$MS365_CLIENT_SECRET \
  --dart-define=SENDER_EMAIL=$SENDER_EMAIL

# 5. Verification
if [ -d "build/web" ]; then
  echo "--- Build Success! ---"
else
  echo "--- Build Failed: Output directory missing ---"
  exit 1
fi
