#!/bin/sh
set -e
FLUTTER_REVISION="2663184aa79047d0a33a14a3b607954f8fdd8730"
git clone https://github.com/flutter/flutter.git --depth 1 --branch stable
cd flutter
git fetch --depth 1 origin "$FLUTTER_REVISION"
git checkout "$FLUTTER_REVISION"
cd ..
export PATH="$PWD/flutter/bin:$PATH"
flutter config --enable-web
flutter --version
flutter pub get
flutter build web --release
