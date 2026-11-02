import AppKit
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var configuration = SharedConfiguration.load()
    @Published var selectedDirectory: String?
    @Published var output = "请添加需要由 SVN Finder 接管的工作副本目录。"
    @Published var isRunning = false

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        guard
            let addIndex = arguments.firstIndex(of: "--add"),
            arguments.indices.contains(addIndex + 1)
        else {
            return
        }
        let path = URL(fileURLWithPath: arguments[addIndex + 1]).standardizedFileURL.path
        if !configuration.watchedDirectories.contains(path) {
            configuration.watchedDirectories.append(path)
            try? SharedConfiguration.save(configuration)
        }
    }

    func addDirectory() {
        let panel = NSOpenPanel()
        panel.title = "选择 SVN 工作副本"
        panel.prompt = "添加"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        for url in panel.urls where !configuration.watchedDirectories.contains(url.path) {
            configuration.watchedDirectories.append(url.standardizedFileURL.path)
        }
        persistConfiguration()
    }

    func removeSelectedDirectory() {
        guard let selectedDirectory else { return }
        configuration.watchedDirectories.removeAll { $0 == selectedDirectory }
        self.selectedDirectory = nil
        persistConfiguration()
    }

    func revealSelectedDirectory() {
        guard let selectedDirectory else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: selectedDirectory)])
    }

    func handle(_ url: URL) {
        guard let request = SVNCommandRequest(url: url) else {
            output = "无法识别命令：\(url.absoluteString)"
            return
        }
        Task { await execute(request) }
    }

    func execute(_ request: SVNCommandRequest) async {
        if request.operation == .terminal {
            openTerminal(at: request.paths[0])
            return
        }

        var arguments: [String]
        switch request.operation {
        case .status:
            arguments = ["status"] + request.paths
        case .update:
            arguments = ["update"] + request.paths
        case .commit:
            guard let message = promptForCommitMessage() else { return }
            arguments = ["commit", "-m", message] + request.paths
        case .add:
            arguments = ["add", "--parents"] + request.paths
        case .revert:
            guard confirmRevert(paths: request.paths) else { return }
            arguments = ["revert", "--depth", "infinity"] + request.paths
        case .cleanup:
            arguments = ["cleanup"] + request.paths.map(Self.directoryPath)
        case .diff:
            arguments = ["diff"] + request.paths
        case .log:
            arguments = ["log", "-l", "50"] + request.paths
        case .terminal:
            return
        }

        isRunning = true
        output = "$ svn \(arguments.map(Self.shellQuoted).joined(separator: " "))\n\n执行中..."
        var result = await SVNRunner.run(arguments: arguments)
        if result.requiresAuthentication,
           let credentials = promptForCredentials() {
            result = await SVNRunner.run(
                arguments: [
                    "--username", credentials.username,
                    "--password-from-stdin",
                    "--non-interactive"
                ] + arguments,
                standardInput: credentials.password + "\n"
            )
        }
        output = "$ svn \(arguments.map(Self.shellQuoted).joined(separator: " "))\n\n\(result.text)"
        isRunning = false
    }

    private func persistConfiguration() {
        do {
            try SharedConfiguration.save(configuration)
            output = "已更新接管目录。Finder 菜单将在几秒内刷新。"
        } catch {
            output = "保存配置失败：\(error.localizedDescription)"
        }
    }

    private func promptForCommitMessage() -> String? {
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 420, height: 24))
        input.placeholderString = "请输入提交说明"
        let alert = NSAlert()
        alert.messageText = "提交 SVN 改动"
        alert.informativeText = "提交说明不能为空。"
        alert.accessoryView = input
        alert.addButton(withTitle: "提交")
        alert.addButton(withTitle: "取消")
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        let message = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if message.isEmpty {
            output = "已取消：提交说明不能为空。"
            return nil
        }
        return message
    }

    private func confirmRevert(paths: [String]) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "确认还原所选改动？"
        alert.informativeText = "未提交的本地修改将被丢弃，此操作无法撤销。\n\n\(paths.joined(separator: "\n"))"
        alert.addButton(withTitle: "还原")
        alert.addButton(withTitle: "取消")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func promptForCredentials() -> (username: String, password: String)? {
        let username = NSTextField(frame: NSRect(x: 0, y: 34, width: 420, height: 24))
        username.placeholderString = "用户名"
        let password = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 420, height: 24))
        password.placeholderString = "密码"

        let fields = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 58))
        fields.addSubview(username)
        fields.addSubview(password)

        let alert = NSAlert()
        alert.messageText = "SVN 需要认证"
        alert.informativeText = "凭据将直接交给本机 svn，并由 svn 的认证缓存管理。"
        alert.accessoryView = fields
        alert.addButton(withTitle: "登录")
        alert.addButton(withTitle: "取消")

        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        let name = username.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !password.stringValue.isEmpty else {
            output = "已取消：用户名和密码不能为空。"
            return nil
        }
        return (name, password.stringValue)
    }

    private func openTerminal(at path: String) {
        let directory = Self.directoryPath(path)
        Task {
            let result = await SVNRunner.runExecutable(
                URL(fileURLWithPath: "/usr/bin/open"),
                arguments: ["-a", "Terminal", directory]
            )
            output = result.text
        }
    }

    private static func directoryPath(_ path: String) -> String {
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), !isDirectory.boolValue {
            return URL(fileURLWithPath: path).deletingLastPathComponent().path
        }
        return path
    }

    private static func shellQuoted(_ value: String) -> String {
        guard value.contains(where: { $0.isWhitespace || "'\"\\$".contains($0) }) else { return value }
        return "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}

private enum SVNRunner {
    struct Result {
        let exitCode: Int32
        let output: String
        let error: String

        var text: String {
            let sections = [output, error].filter { !$0.isEmpty }
            let body = sections.isEmpty ? "命令没有输出。" : sections.joined(separator: "\n")
            return "\(body)\n\n退出码：\(exitCode)"
        }

        var requiresAuthentication: Bool {
            exitCode != 0 && output.contains("E170001")
        }
    }

    static func run(
        arguments: [String],
        standardInput: String? = nil
    ) async -> Result {
        guard let executable = svnExecutable else {
            return Result(
                exitCode: 127,
                output: "",
                error: "未找到 svn。请先执行：brew install subversion"
            )
        }
        return await runExecutable(
            executable,
            arguments: arguments,
            standardInput: standardInput
        )
    }

    static func runExecutable(
        _ executable: URL,
        arguments: [String],
        standardInput: String? = nil
    ) async -> Result {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let combinedOutput = Pipe()
                process.executableURL = executable
                process.arguments = arguments
                process.standardOutput = combinedOutput
                process.standardError = combinedOutput
                process.environment = ProcessInfo.processInfo.environment.merging([
                    "LANG": "zh_CN.UTF-8",
                    "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
                ]) { _, new in new }
                do {
                    if let standardInput {
                        let input = Pipe()
                        process.standardInput = input
                        try process.run()
                        input.fileHandleForWriting.write(Data(standardInput.utf8))
                        try? input.fileHandleForWriting.close()
                    } else {
                        process.standardInput = FileHandle.nullDevice
                        try process.run()
                    }
                    let outputData = combinedOutput.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    continuation.resume(returning: Result(
                        exitCode: process.terminationStatus,
                        output: String(decoding: outputData, as: UTF8.self)
                            .trimmingCharacters(in: .whitespacesAndNewlines),
                        error: ""
                    ))
                } catch {
                    continuation.resume(returning: Result(
                        exitCode: 126,
                        output: "",
                        error: error.localizedDescription
                    ))
                }
            }
        }
    }

    private static var svnExecutable: URL? {
        ["/opt/homebrew/bin/svn", "/usr/local/bin/svn", "/usr/bin/svn"]
            .first(where: FileManager.default.isExecutableFile(atPath:))
            .map(URL.init(fileURLWithPath:))
    }
}
