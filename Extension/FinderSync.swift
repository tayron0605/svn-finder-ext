import AppKit
import FinderSync
import os

final class FinderSync: FIFinderSync {
    private let logger = Logger(
        subsystem: "com.tayron.SVNFinder.Extension",
        category: "FinderSync"
    )
    private var selectedURLs: [URL] = []

    override init() {
        super.init()
        reloadConfiguration()
        logger.info("Finder Sync extension started")
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(configurationDidChange),
            name: SharedConfiguration.changeNotification,
            object: nil
        )
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        selectedURLs = currentSelection()
        guard !selectedURLs.isEmpty else {
            logger.debug("Menu requested without a selected or targeted URL")
            return nil
        }
        logger.info(
            "Menu requested for \(self.selectedURLs.count, privacy: .public) item(s)"
        )

        let menu = NSMenu(title: "SVN Finder")
        let rootItem = NSMenuItem(title: "SVN Finder", action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: "SVN Finder")

        add(.status, to: submenu)
        add(.update, to: submenu)
        submenu.addItem(.separator())
        add(.commit, to: submenu)
        add(.add, to: submenu)
        add(.revert, to: submenu)
        submenu.addItem(.separator())
        add(.diff, to: submenu)
        add(.log, to: submenu)
        add(.cleanup, to: submenu)
        submenu.addItem(.separator())
        add(.terminal, to: submenu)

        rootItem.submenu = submenu
        menu.addItem(rootItem)
        return menu
    }

    private func add(_ operation: SVNOperation, to menu: NSMenu) {
        let item = NSMenuItem(
            title: operation.title,
            action: #selector(runCommand(_:)),
            keyEquivalent: ""
        )
        item.target = self
        item.representedObject = operation.rawValue
        menu.addItem(item)
    }

    @objc private func runCommand(_ sender: NSMenuItem) {
        guard
            let rawValue = sender.representedObject as? String,
            let operation = SVNOperation(rawValue: rawValue),
            let url = SVNCommandRequest(
                operation: operation,
                paths: selectedURLs.map(\.path)
            ).url
        else {
            logger.error("Could not create command URL")
            return
        }
        logger.info("Opening command \(operation.rawValue, privacy: .public)")
        NSWorkspace.shared.open(url)
    }

    @objc private func configurationDidChange(_ notification: Notification) {
        reloadConfiguration()
    }

    private func reloadConfiguration() {
        let configuration = SharedConfiguration.load()
        let urls = configuration.watchedDirectories.map {
            URL(fileURLWithPath: $0, isDirectory: true).standardizedFileURL
        }
        FIFinderSyncController.default().directoryURLs = Set(urls)
        logger.info("Watching \(urls.count, privacy: .public) directorie(s)")
    }

    private func currentSelection() -> [URL] {
        let controller = FIFinderSyncController.default()
        if let selected = controller.selectedItemURLs(), !selected.isEmpty {
            return selected
        }
        if let target = controller.targetedURL() {
            return [target]
        }
        return []
    }
}
