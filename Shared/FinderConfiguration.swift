import Foundation
import Darwin

struct FinderConfiguration: Codable, Equatable {
    var watchedDirectories: [String] = []
}

enum SharedConfiguration {
    static let changeNotification = Notification.Name("com.tayron.SVNFinder.configurationChanged")

    static var fileURL: URL {
        realHomeDirectory
            .appendingPathComponent("Library/Application Support/SVNFinder", isDirectory: true)
            .appendingPathComponent("configuration.json")
    }

    private static var realHomeDirectory: URL {
        guard
            let record = getpwuid(getuid()),
            let home = record.pointee.pw_dir
        else {
            return FileManager.default.homeDirectoryForCurrentUser
        }
        return URL(fileURLWithPath: String(cString: home), isDirectory: true)
    }

    static func load() -> FinderConfiguration {
        guard
            let data = try? Data(contentsOf: fileURL),
            let configuration = try? JSONDecoder().decode(FinderConfiguration.self, from: data)
        else {
            return FinderConfiguration()
        }
        return configuration
    }

    static func save(_ configuration: FinderConfiguration) throws {
        let parent = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let normalized = FinderConfiguration(
            watchedDirectories: Array(Set(configuration.watchedDirectories.map {
                URL(fileURLWithPath: $0).standardizedFileURL.path
            })).sorted()
        )
        let data = try JSONEncoder.pretty.encode(normalized)
        try data.write(to: fileURL, options: .atomic)
        DistributedNotificationCenter.default().postNotificationName(
            changeNotification,
            object: nil,
            deliverImmediately: true
        )
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
}
