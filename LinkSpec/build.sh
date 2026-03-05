#!/bin/bash
set -e  # Exit immediately on any error

# LinkSpec: Web Deployment Build Script
# ─────────────────────────────────────

# 1. Setup Flutter SDK (Linux) — Vercel runs on Linux
echo "--- Installing Flutter SDK (stable) ---"
if [ ! -d "flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable --depth 1
fi
export PATH="$PATH:$(pwd)/flutter/bin"

# Pre-cache web SDK artifacts
flutter precache --web

# 2. Verify environment
flutter doctor -v
flutter --version

# 3. Handle Dependencies
echo "--- Cleaning & Getting Dependencies ---"
flutter clean
flutter pub get

# 4. Perform Release Build
# Renderer: CanvasKit (Required for high-performance infographics)
echo "--- Building Flutter Web (Release) ---"
flutter build web --release --web-renderer canvaskit

# 5. Verify build output exists
if [ ! -f "build/web/index.html" ]; then
  echo "ERROR: build/web/index.html not found! Build may have failed."
  exit 1
fi

echo "--- Build Complete: LinkSpec is ready for Vercel deployment ---"
echo "Build output directory contents:"
ls -la build/web/
