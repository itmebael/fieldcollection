#!/bin/sh
set -e
FLUTTER_VERSION="3.29.2"
git clone https://github.com/flutter/flutter.git --depth 1 --branch "$FLUTTER_VERSION"
cd flutter
cd ..
export PATH="$PWD/flutter/bin:$PATH"
flutter config --enable-web
flutter --version
flutter pub get
flutter build web --release
