#!/bin/zsh
set -e
cd "$(dirname "$0")"
APP=build/TempBar.app
rm -rf build && mkdir -p $APP/Contents/MacOS
clang -c src/sensors.c -o build/sensors.o
swiftc -O -parse-as-library -import-objc-header src/sensors.h src/App.swift build/sensors.o \
  -framework IOKit -o $APP/Contents/MacOS/TempBar
cp Info.plist $APP/Contents/
mkdir -p $APP/Contents/Resources && cp AppIcon.icns $APP/Contents/Resources/
codesign --force --sign - $APP
echo "OK: $APP"
