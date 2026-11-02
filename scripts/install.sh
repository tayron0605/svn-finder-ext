#!/bin/zsh
set -euo pipefail

ROOT_DIR=${0:A:h:h}
BUILD_DIR="$ROOT_DIR/.build"
APP_NAME="SVNFinder.app"
SOURCE_APP="$BUILD_DIR/Build/Products/Release/$APP_NAME"
INSTALL_DIR="$HOME/Applications"
INSTALL_APP="$INSTALL_DIR/$APP_NAME"
EXTENSION_ID="com.tayron.SVNFinder.Extension"
EXTENSION_PATH="$INSTALL_APP/Contents/PlugIns/SVNFinderExtension.appex"
EXTENSION_ENTITLEMENTS="$ROOT_DIR/Extension/SVNFinderExtension.entitlements"
WATCH_DIR="${1:-}"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "缺少 XcodeGen，请先执行：brew install xcodegen" >&2
  exit 1
fi

if ! command -v svn >/dev/null 2>&1; then
  echo "缺少 Subversion，请先执行：brew install subversion" >&2
  exit 1
fi

if [[ -n "$WATCH_DIR" && ! -d "$WATCH_DIR/.svn" ]]; then
  echo "不是 SVN 工作副本：$WATCH_DIR" >&2
  exit 1
fi

echo "生成 Xcode 工程..."
xcodegen generate --spec "$ROOT_DIR/project.yml" --project "$ROOT_DIR"

echo "构建 SVN Finder..."
xcodebuild \
  -project "$ROOT_DIR/SVNFinder.xcodeproj" \
  -scheme SVNFinder \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  CODE_SIGNING_ALLOWED=NO \
  build

mkdir -p "$INSTALL_DIR"
rm -rf "$INSTALL_APP"
ditto "$SOURCE_APP" "$INSTALL_APP"

echo "签名并注册 Finder 扩展..."
codesign --force --sign - --entitlements "$EXTENSION_ENTITLEMENTS" "$EXTENSION_PATH"
codesign --force --sign - "$INSTALL_APP"
pluginkit -a "$EXTENSION_PATH"
pluginkit -e use -i "$EXTENSION_ID"

if [[ -n "$WATCH_DIR" ]]; then
  open "$INSTALL_APP" --args --add "${WATCH_DIR:A}"
else
  open "$INSTALL_APP"
fi

killall Finder 2>/dev/null || true

echo
echo "安装完成：$INSTALL_APP"
echo "扩展标识：$EXTENSION_ID"
if [[ -n "$WATCH_DIR" ]]; then
  echo "接管目录：${WATCH_DIR:A}"
fi
