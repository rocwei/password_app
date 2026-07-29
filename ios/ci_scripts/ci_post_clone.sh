#!/bin/sh

set -eu

cd "$CI_PRIMARY_REPOSITORY_PATH"

# Flutter is not preinstalled in Xcode Cloud. Pin the SDK used by this project
# so the generated Swift package matches the locally verified toolchain.
FLUTTER_SDK_PATH="$CI_WORKSPACE/flutter-sdk"
git clone https://github.com/flutter/flutter.git \
  --depth 1 \
  --branch 3.44.0 \
  "$FLUTTER_SDK_PATH"
export PATH="$FLUTTER_SDK_PATH/bin:$PATH"

flutter precache --ios
flutter pub get

if ! command -v pod >/dev/null 2>&1; then
  export HOMEBREW_NO_AUTO_UPDATE=1
  brew install cocoapods
fi

cd ios
pod install
