#!/bin/sh
set -e

if [ -f firebase-tests/package.json ]; then
  if [ ! -d firebase-tests/node_modules ]; then
    (cd firebase-tests && npm install)
  fi

  npx --prefix firebase-tests firebase emulators:start --only firestore,auth --project cookies-c6de0 --ui=false --quiet > /tmp/firebase-emulators.log 2>&1 &
  echo $! > /tmp/firebase-emulators.pid

  for i in $(seq 1 30); do
    if nc -z 127.0.0.1 8080 && nc -z 127.0.0.1 9099; then
      break
    fi
    sleep 1
  done
fi
