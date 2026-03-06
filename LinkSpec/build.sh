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
flutter build web --release

# 5. Verification
if [ -d "build/web" ]; then
  echo "--- Build Success! ---"
else
  echo "--- Build Failed: Output directory missing ---"
  exit 1
fi
