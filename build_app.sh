#!/bin/bash
set -e

SDK_PATH="/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"

DIST_DIR="dist"

build_target() {
    local MODE="$1"

    mkdir -p "$DIST_DIR"

    if [ "$MODE" = "debug" ]; then
        BUNDLE_ID="com.hycity.timer.debug"
        BASE_NAME="Timer-Debug"
        LOCALIZED_NAME="倒计时 (Debug)"
        APP_DIR="$DIST_DIR/Timer-Debug.app"
        BUILD_CONF="debug"
    else
        BUNDLE_ID="com.hycity.timer"
        BASE_NAME="Timer"
        LOCALIZED_NAME="倒计时"
        APP_DIR="$DIST_DIR/Timer.app"
        BUILD_CONF="release"
    fi

    # 清理旧中文名称产物以避免 LaunchServices 缓存混淆
    for old_app in "$DIST_DIR/倒计时.app" "$DIST_DIR/倒计时 (Debug).app"; do
        if [ -d "$old_app" ]; then
            if [ -x "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister" ]; then
                /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "$old_app" 2>/dev/null || true
            fi
            rm -rf "$old_app"
        fi
    done

    echo "=========================================="
    echo "正在构建 $MODE 版本: $LOCALIZED_NAME"
    echo "Bundle ID: $BUNDLE_ID"
    echo "目标产物: $APP_DIR (基准名: $BASE_NAME)"
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

    # 拷贝并动态配置基准 Info.plist（基准名与磁盘文件名保持一致，消除 wasRenamed 误判）
    cp "Sources/TimerApp/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
    plutil -replace CFBundleIdentifier -string "$BUNDLE_ID" "$CONTENTS_DIR/Info.plist"
    plutil -replace CFBundleDisplayName -string "$BASE_NAME" "$CONTENTS_DIR/Info.plist"
    plutil -replace CFBundleName -string "$BASE_NAME" "$CONTENTS_DIR/Info.plist"

    # 拷贝本地化语言包 (.lproj)
    for lproj in Sources/TimerApp/Resources/*.lproj; do
        if [ -d "$lproj" ]; then
            cp -r "$lproj" "$RESOURCES_DIR/"
        fi
    done

    # 若为 Debug 环境，更新各语言包显示名称
    if [ "$MODE" = "debug" ]; then
        for str_file in "$RESOURCES_DIR"/*zh*.lproj/InfoPlist.strings; do
            if [ -f "$str_file" ]; then
                sed -i '' "s/\"CFBundleDisplayName\" = \".*\";/\"CFBundleDisplayName\" = \"$LOCALIZED_NAME\";/g" "$str_file"
                sed -i '' "s/\"CFBundleName\" = \".*\";/\"CFBundleName\" = \"$LOCALIZED_NAME\";/g" "$str_file"
            fi
        done
        if [ -f "$RESOURCES_DIR/en.lproj/InfoPlist.strings" ]; then
            sed -i '' "s/\"CFBundleDisplayName\" = \".*\";/\"CFBundleDisplayName\" = \"Timer (Debug)\";/g" "$RESOURCES_DIR/en.lproj/InfoPlist.strings"
            sed -i '' "s/\"CFBundleName\" = \".*\";/\"CFBundleName\" = \"Timer (Debug)\";/g" "$RESOURCES_DIR/en.lproj/InfoPlist.strings"
        fi
    fi

    # 强制刷新系统 LaunchServices 注册信息
    if [ -x "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister" ]; then
        /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP_DIR" || true
    fi

    echo "✓ 成功构建并打包: $APP_DIR (显示名称: $LOCALIZED_NAME)"
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
