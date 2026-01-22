#!/bin/bash
set -e

echo "Building MacTiler..."
swift build -c release

echo "Creating app bundle..."
rm -rf MacTiler.app
mkdir -p MacTiler.app/Contents/MacOS
mkdir -p MacTiler.app/Contents/Resources

cp .build/release/mactiler MacTiler.app/Contents/MacOS/MacTiler
cp Sources/mactiler/App/Info.plist MacTiler.app/Contents/

echo "Done! App bundle created at ./MacTiler.app"
echo ""
echo "To install:"
echo "  cp -r MacTiler.app ~/Applications/"
echo ""
echo "To run:"
echo "  open ~/Applications/MacTiler.app"
