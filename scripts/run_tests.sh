#!/bin/bash
set -euo pipefail

DESTINATION=${DESTINATION:-platform=iOS Simulator,name=iPhone 15 Pro}

patch_project_format() {
  for f in "Cookies.xcodeproj/project.pbxproj" "Pods/Pods.xcodeproj/project.pbxproj"; do
    if [ -f "$f" ]; then
      perl -0pi -e 's/objectVersion = 77;/objectVersion = 60;/g' "$f"
      perl -0pi -e 's/compatibilityVersion = "Xcode 16.0"/compatibilityVersion = "Xcode 15.0"/g' "$f"
    fi
  done
}

if [ -f firebase-tests/package.json ]; then
  if [ ! -d firebase-tests/node_modules ]; then
    (cd firebase-tests && npm install)
  fi

  patch_project_format

  npx --prefix firebase-tests firebase emulators:exec --only firestore,auth --project cookies-c6de0 \
    "USE_FIREBASE_EMULATORS=1 FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 xcodebuild test -workspace Cookies.xcworkspace -scheme Cookies -destination \"$DESTINATION\" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO && npm test --prefix firebase-tests"
else
  patch_project_format

  xcodebuild test \
    -workspace Cookies.xcworkspace \
    -scheme Cookies \
    -destination "$DESTINATION" \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
fi
