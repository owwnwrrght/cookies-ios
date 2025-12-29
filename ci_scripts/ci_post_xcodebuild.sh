#!/bin/sh
set -e

if [ -f firebase-tests/package.json ]; then
  if [ ! -d firebase-tests/node_modules ]; then
    (cd firebase-tests && npm install)
  fi

  npm test --prefix firebase-tests
fi

if [ -f /tmp/firebase-emulators.pid ]; then
  kill $(cat /tmp/firebase-emulators.pid) || true
fi
