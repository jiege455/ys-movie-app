#!/bin/bash
set -e

# Arguments
APP_NAME="$1"
PACKAGE_NAME="$2"
APP_VERSION="$3"
ICON_URL="$4"
SPLASH_URL="$5"
API_BASE_URL="$6"

echo "--------------------------------------------------"
echo "Preparing build for $APP_NAME ($PACKAGE_NAME) v$APP_VERSION"
echo "API URL: $API_BASE_URL"
echo "--------------------------------------------------"

# 1. Download Assets
# Ensure directories exist
mkdir -p assets/images

echo "Downloading Icon from $ICON_URL..."
curl -L -o assets/images/logo.png "$ICON_URL"

echo "Downloading Splash from $SPLASH_URL..."
curl -L -o assets/images/splash.png "$SPLASH_URL"

# 2. Update Android Manifest Label
echo "Updating Android Manifest label..."
if [[ "$OSTYPE" == "darwin"* ]]; then
  sed -i '' "s/android:label=\"[^\"]*\"/android:label=\"$APP_NAME\"/" android/app/src/main/AndroidManifest.xml
else
  sed -i "s/android:label=\"[^\"]*\"/android:label=\"$APP_NAME\"/" android/app/src/main/AndroidManifest.xml
fi

# 3. Update iOS Display Name
echo "Updating iOS Bundle Display Name..."
# Use PlistBuddy if available (macOS), otherwise use simple sed (Linux/CI)
if command -v /usr/libexec/PlistBuddy &> /dev/null; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $APP_NAME" ios/Runner/Info.plist
    /usr/libexec/PlistBuddy -c "Set :CFBundleName $APP_NAME" ios/Runner/Info.plist
else
    # Simple sed replacement for XML plist (CI environment usually)
    # This is a bit fragile but works for standard Flutter Info.plist structure
    sed -i "s/<key>CFBundleDisplayName<\/key>[[:space:]]*<string>.*<\/string>/<key>CFBundleDisplayName<\/key>\n\t<string>$APP_NAME<\/string>/" ios/Runner/Info.plist
    sed -i "s/<key>CFBundleName<\/key>[[:space:]]*<string>.*<\/string>/<key>CFBundleName<\/key>\n\t<string>$APP_NAME<\/string>/" ios/Runner/Info.plist
fi

# 4. Update Version in pubspec.yaml
echo "Updating pubspec.yaml version..."
if [[ "$OSTYPE" == "darwin"* ]]; then
  sed -i '' "s/^version: .*/version: $APP_VERSION/" pubspec.yaml
else
  sed -i "s/^version: .*/version: $APP_VERSION/" pubspec.yaml
fi

# 5. (Optional) Update Package Name / Application ID
# This is complex because it involves moving files (Java/Kotlin package structure).
# For now, we will just update the build.gradle applicationId if possible,
# but note that Flutter often requires the directory structure to match.
# To keep it safe for "Cloud Build" without breaking code references, we might skip changing the package structure
# and only change the applicationId in build.gradle.

echo "Updating Android Application ID..."
if [[ "$OSTYPE" == "darwin"* ]]; then
  sed -i '' "s/applicationId \".*\"/applicationId \"$PACKAGE_NAME\"/" android/app/build.gradle
else
  sed -i "s/applicationId \".*\"/applicationId \"$PACKAGE_NAME\"/" android/app/build.gradle
fi

echo "Build preparation complete."
