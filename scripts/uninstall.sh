#!/bin/zsh
set -euo pipefail

APP_PATH="$HOME/Applications/SVNFinder.app"
EXTENSION_ID="com.tayron.SVNFinder.Extension"
EXTENSION_PATH="$APP_PATH/Contents/PlugIns/SVNFinderExtension.appex"

pluginkit -e ignore -i "$EXTENSION_ID" 2>/dev/null || true
pluginkit -r "$EXTENSION_PATH" 2>/dev/null || true
rm -rf "$APP_PATH"
killall Finder 2>/dev/null || true

echo "SVN Finder 已卸载。配置仍保留在 ~/Library/Application Support/SVNFinder。"
