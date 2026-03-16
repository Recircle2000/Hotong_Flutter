#!/bin/sh
set -e

cd "$CI_PRIMARY_REPOSITORY_PATH"

if [ -z "$FLUTTER_ROOT" ]; then
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$HOME/flutter"
  FLUTTER_ROOT="$HOME/flutter"
fi

export PATH="$FLUTTER_ROOT/bin:$PATH"

flutter --version
flutter precache --ios
flutter pub get
flutter build ios --config-only --no-codesign

cd ios
pod install
