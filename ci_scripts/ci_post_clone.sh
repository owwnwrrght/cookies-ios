#!/bin/sh
set -e

if ! command -v pod >/dev/null 2>&1; then
  brew install cocoapods
fi

if ! command -v java >/dev/null 2>&1; then
  brew install --cask temurin
fi

pod install

if [ -f firebase-tests/package.json ]; then
  (cd firebase-tests && npm install)
fi
