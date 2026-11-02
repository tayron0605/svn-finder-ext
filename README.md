# SVN Finder

一个面向 macOS 的轻量 SVN Finder 右键扩展。它由宿主 App 和 Finder Sync
Extension 组成，使用本机安装的 Apache Subversion 执行命令。

## 功能

- 管理需要显示右键菜单的 SVN 工作副本目录
- 检查状态、更新、提交和加入版本控制
- 还原、清理工作副本
- 查看差异和最近 50 条日志
- 在终端中打开所选目录
- 命令在宿主 App 中执行，显示标准输出、错误输出和退出码

## 环境

- macOS 13 或更高版本
- Xcode
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- Apache Subversion

```bash
brew install xcodegen subversion
```

## 构建和安装

传入工作副本路径时，安装完成后会自动添加该目录：

```bash
./scripts/install.sh /path/to/working-copy
```

也可以不传路径，然后在 SVN Finder App 中手动添加：

```bash
./scripts/install.sh
```

安装脚本会：

1. 生成 `SVNFinder.xcodeproj`
2. 构建 Release App
3. 使用 ad-hoc 签名安装到 `~/Applications/SVNFinder.app`
4. 注册并启用 Finder Sync Extension
5. 重启 Finder

若菜单未出现，请在“系统设置 → 通用 → 登录项与扩展 → 扩展 → Finder”
中确认 SVN Finder 已启用。

## 使用

在 Finder 中右键已接管目录内的文件或文件夹，打开 `SVN Finder` 子菜单。
提交和还原操作会由宿主 App 二次确认。相同文件的 SVN 命令不会在 Finder
扩展进程内执行，避免阻塞 Finder。

首次操作“文稿”“桌面”等受保护目录时，macOS 会请求目录访问权限，请选择
“允许”。该权限仅用于宿主 App 调用本机 `svn` 处理所选工作副本。

若 Apache SVN 尚未缓存仓库凭据，宿主 App 会在首次联网操作时要求输入用户名
和密码。密码通过标准输入交给 `svn`，不会出现在命令行或命令输出中。

旧版 SVN 工作副本可先升级：

```bash
svn upgrade /path/to/working-copy
```

## 测试

```bash
xcodegen generate --spec project.yml --project .
xcodebuild -project SVNFinder.xcodeproj -scheme SVNFinder \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO test
```

## 卸载

```bash
./scripts/uninstall.sh
```

配置保存在：

```text
~/Library/Application Support/SVNFinder/configuration.json
```

## 已知限制

Finder Sync API 不允许扩展检查其他扩展是否已经为当前菜单提供命令，因此
无法自动判断 SnailSVN 菜单是否存在。可以通过 SVN Finder App 的接管目录
控制菜单显示范围。
