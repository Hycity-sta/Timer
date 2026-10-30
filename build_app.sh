#!/bin/bash
set -e

SDK_PATH="/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"

build_target() {
    local MODE="$1"

    if [ "$MODE" = "debug" ]; then
        APP_DIR="Timer-Debug.app"
        BUNDLE_ID="com.hycity.timer.debug"
        APP_NAME="倒计时 (Debug)"
        BUILD_CONF="debug"
    else
        APP_DIR="Timer.app"
        BUNDLE_ID="com.hycity.timer"
        APP_NAME="倒计时"
        BUILD_CONF="release"
    fi

    echo "=========================================="
    echo "正在构建 $MODE 版本: $APP_NAME"
    echo "Bundle ID: $BUNDLE_ID"
    echo "目标产物: $APP_DIR"
    echo "=========================================="

    swift build -c "$BUILD_CONF" \
      -Xswiftc -target -Xswiftc arm64-apple-macos27.0 \
      -Xswiftc -sdk -Xswiftc "$SDK_PATH"

    CONTENTS_DIR="$APP_DIR/Contents"
    MACOS_DIR="$CONTENTS_DIR/MacOS"
    RESOURCES_DIR="$CONTENTS_DIR/Resources"

    rm -rf "$APP_DIR"
    mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

    # 拷贝可执行二进制
    cp ".build/$BUILD_CONF/TimerApp" "$MACOS_DIR/TimerApp"

    # 拷贝资源文件
    if [ -d ".build/$BUILD_CONF/TimerApp_TimerApp.bundle" ]; then
        cp -r ".build/$BUILD_CONF/TimerApp_TimerApp.bundle" "$RESOURCES_DIR/"
    fi
    if [ -f "Sources/TimerApp/Resources/AppIcon.icns" ]; then
        cp "Sources/TimerApp/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
    fi

    # 写入 Info.plist (增加 LSHasLocalizedDisplayName 与 CFBundleLocalizations 确保系统 Dock 和 Finder 正确识别中文名称)
    cat << EOF > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_CN</string>
    <key>CFBundleLocalizations</key>
    <array>
        <string>zh-Hans</string>
        <string>zh_CN</string>
    </array>
    <key>LSHasLocalizedDisplayName</key>
    <true/>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleExecutable</key>
    <string>TimerApp</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
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

    # 写入本地化语言包 (zh-Hans 与 zh_CN)
    mkdir -p "$RESOURCES_DIR/zh-Hans.lproj" "$RESOURCES_DIR/zh_CN.lproj"
    cat << EOF > "$RESOURCES_DIR/zh-Hans.lproj/InfoPlist.strings"
/* Localized versions of Info.plist keys */
"CFBundleDisplayName" = "$APP_NAME";
"CFBundleName" = "$APP_NAME";
EOF
    cp "$RESOURCES_DIR/zh-Hans.lproj/InfoPlist.strings" "$RESOURCES_DIR/zh_CN.lproj/InfoPlist.strings"

    # 强制刷新系统 LaunchServices 注册信息
    if [ -x "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister" ]; then
        /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP_DIR" || true
    fi

    echo "✓ 成功构建并打包: $APP_DIR (显示名称: $APP_NAME)"
    echo ""
}

TARGET="${1:-release}"

case "$TARGET" in
    debug)
        build_target "debug"
        ;;
    release)
        build_target "release"
        ;;
    all)
        build_target "release"
        build_target "debug"
        ;;
    *)
        echo "使用方法: ./build_app.sh [release|debug|all]"
        echo "默认构建 release 版本"
        exit 1
        ;;
esac
