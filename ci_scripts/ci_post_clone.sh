#!/bin/sh
set -e

if ! command -v pod >/dev/null 2>&1; then
  brew install cocoapods
fi

if ! command -v java >/dev/null 2>&1; then
  brew install --cask temurin
fi

# Create GoogleService-Info.plist from environment secret
# Set GOOGLE_SERVICE_INFO_PLIST_BASE64 in Xcode Cloud secrets
if [ -n "$GOOGLE_SERVICE_INFO_PLIST_BASE64" ]; then
  echo "Creating GoogleService-Info.plist from environment secret..."
  mkdir -p "$CI_PRIMARY_REPOSITORY_PATH/Cookies/Resources"
  echo "$GOOGLE_SERVICE_INFO_PLIST_BASE64" | base64 --decode > "$CI_PRIMARY_REPOSITORY_PATH/Cookies/Resources/GoogleService-Info.plist"
  echo "GoogleService-Info.plist created successfully"
else
  echo "Warning: GOOGLE_SERVICE_INFO_PLIST_BASE64 not set. Firebase features may not work."
fi

pod install

if [ -f firebase-tests/package.json ]; then
  (cd firebase-tests && npm install)
fi
