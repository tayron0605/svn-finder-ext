import Foundation

enum SVNOperation: String, CaseIterable {
    case status
    case update
    case commit
    case add
    case revert
    case cleanup
    case diff
    case log
    case terminal

    var title: String {
        switch self {
        case .status: return "检查状态"
        case .update: return "更新"
        case .commit: return "提交..."
        case .add: return "加入版本控制"
        case .revert: return "还原..."
        case .cleanup: return "清理工作副本"
        case .diff: return "查看差异"
        case .log: return "查看日志"
        case .terminal: return "在终端中打开"
        }
    }
}

struct SVNCommandRequest: Equatable {
    let operation: SVNOperation
    let paths: [String]

    init(operation: SVNOperation, paths: [String]) {
        self.operation = operation
        self.paths = paths
    }

    init?(url: URL) {
        guard
            url.scheme == "svn-finder",
            url.host == "run",
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let operationName = components.queryItems?.first(where: { $0.name == "operation" })?.value,
            let operation = SVNOperation(rawValue: operationName)
        else {
            return nil
        }
        let paths = components.queryItems?
            .filter { $0.name == "path" }
            .compactMap(\.value) ?? []
        guard !paths.isEmpty else { return nil }
        self.operation = operation
        self.paths = paths
    }

    var url: URL? {
        var components = URLComponents()
        components.scheme = "svn-finder"
        components.host = "run"
        components.queryItems = [
            URLQueryItem(name: "operation", value: operation.rawValue)
        ] + paths.map { URLQueryItem(name: "path", value: $0) }
        return components.url
    }
}
