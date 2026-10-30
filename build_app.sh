#!/bin/bash
set -e

SDK_PATH="/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"

# 1. 使用 macOS 27 SDK 编译
echo "正在使用 macOS 27.0 SDK 构建..."
swift build -c release \
  -Xswiftc -target -Xswiftc arm64-apple-macos27.0 \
  -Xswiftc -sdk -Xswiftc "$SDK_PATH"

# 2. 组装 Timer.app
APP_DIR="Timer.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# 拷贝二进制
cp .build/release/TimerApp "$MACOS_DIR/TimerApp"

# 拷贝资源
if [ -d ".build/release/TimerApp_TimerApp.bundle" ]; then
    cp -r ".build/release/TimerApp_TimerApp.bundle" "$RESOURCES_DIR/"
fi
if [ -f "Sources/TimerApp/Resources/AppIcon.icns" ]; then
    cp "Sources/TimerApp/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

# 写入 Info.plist (指定 LSMinimumSystemVersion 为 27.0，启用 macOS 27 Liquid Glass 特性)
cat << 'EOF' > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_CN</string>
    <key>CFBundleExecutable</key>
    <string>TimerApp</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.hycity.timer</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>倒计时</string>
    <key>CFBundleDisplayName</key>
    <string>倒计时</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>27.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSRequiresAquaSystemAppearance</key>
    <false/>
</dict>
</plist>
EOF

echo "✓ 成功构建并打包 macOS 27 原生应用: $APP_DIR"
