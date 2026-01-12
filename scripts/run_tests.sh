#!/bin/bash
set -euo pipefail

DESTINATION=${DESTINATION:-platform=iOS Simulator,name=iPhone 16 Pro}

# Use xcpretty for cleaner output if available
if command -v xcpretty >/dev/null 2>&1; then
  XCPRETTY="xcpretty --color"
else
  XCPRETTY="cat"
fi

xcodebuild_test() {
  set -o pipefail
  xcodebuild test \
    -workspace Cookies.xcworkspace \
    -scheme Cookies \
    -destination "$DESTINATION" \
    -only-testing:CookiesTests \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    2>&1 | $XCPRETTY
}

if [ -f firebase-tests/package.json ]; then
  if [ ! -d firebase-tests/node_modules ]; then
    (cd firebase-tests && npm install)
  fi

  USE_FIREBASE_EMULATORS=1 \
  FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 \
  FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 \
  npx --prefix firebase-tests firebase emulators:exec \
    --only firestore,auth \
    --project cookies-c6de0 \
    "cd $(pwd) && xcodebuild test -workspace Cookies.xcworkspace -scheme Cookies -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:CookiesTests CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO && npm test --prefix firebase-tests"
else
  xcodebuild_test
fi
