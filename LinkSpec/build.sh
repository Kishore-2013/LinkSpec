#!/bin/bash

# LinkSpec: Web Deployment Build Script
# ─────────────────────────────────────

# 1. Setup Flutter SDK (Linux)
echo "--- Installing Flutter SDK (stable) ---"
if [ ! -d "flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable --depth 1
fi
export PATH="$PATH:$(pwd)/flutter/bin"

# 2. Verify environment
flutter doctor -v
flutter --version

# 3. Handle Web Dependencies
echo "--- Cleaning & Getting Dependencies ---"
flutter clean
flutter pub get

# 4. Perform Release Build
# Renderer: CanvasKit (Required for high-performance infographics)
echo "--- Building Flutter Web (Release) ---"
flutter build web --release --web-renderer canvaskit

# 5. Move output to root level for Vercel (Optional, but vercel.json assumes index.html is reachable)
# Vercel typically serves from the root if not configured otherwise.
# We will point Vercel's 'output' to 'build/web' in the dashboard or via config if needed.
# For now, let's ensure the build succeeds.

echo "--- Build Complete: LinkSpec is ready for Vercel deployment ---"
