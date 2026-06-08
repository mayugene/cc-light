import Cocoa

// MARK: - State

enum CCState: String, Codable {
    case idle, busy, waiting

    var emoji: String {
        switch self {
        case .idle: return "🟢"
        case .busy: return "🔴"
        case .waiting: return "🟡"
        }
    }

    var label: String {
        switch self {
        case .idle: return "Idle"
        case .busy: return "Working..."
        case .waiting: return "Waiting"
        }
    }

    var priority: Int {
        switch self {
        case .busy: return 2
        case .waiting: return 1
        case .idle: return 0
        }
    }
}

struct SessionState: Codable {
    let state: CCState
    let session_id: String?
    let ts: Int?

    var id: String { session_id ?? "_default" }
    var shortId: String { String((session_id ?? "default").prefix(8)) }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var timer: Timer?
    var sessions: [SessionState] = []
    let stateDir = "/tmp/cc-light"
    let staleThreshold: TimeInterval = 300

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "🟢"

        updateMenu()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        refresh()
    }

    func refresh() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: stateDir) else {
            DispatchQueue.main.async { self.statusItem.button?.title = "🟢" }
            return
        }

        let now = Date()
        var results: [SessionState] = []

        for file in files where file.hasSuffix(".json") {
            let path = "\(stateDir)/\(file)"
            guard let data = fm.contents(atPath: path),
                  let s = try? JSONDecoder().decode(SessionState.self, from: data) else { continue }
            if let ts = s.ts, now.timeIntervalSince(Date(timeIntervalSince1970: Double(ts))) > staleThreshold { continue }
            results.append(s)
        }

        sessions = results.sorted { $0.state.priority > $1.state.priority }

        let agg: CCState
        if sessions.contains(where: { $0.state == .busy }) { agg = .busy }
        else if sessions.contains(where: { $0.state == .waiting }) { agg = .waiting }
        else { agg = .idle }

        DispatchQueue.main.async {
            self.statusItem.button?.title = agg.emoji
            self.updateMenu()
        }
    }

    func updateMenu() {
        let menu = NSMenu()

        if sessions.isEmpty {
            menu.addItem(NSMenuItem(title: "No active sessions", action: nil, keyEquivalent: ""))
        } else {
            for s in sessions {
                let title = "\(s.state.emoji)  \(s.shortId)  —  \(s.state.label)"
                menu.addItem(NSMenuItem(title: title, action: nil, keyEquivalent: ""))
            }
        }

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }
}

// MARK: - Main

@main
struct Main {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
