import Cocoa

// MARK: - State

enum CCState: String, Codable {
    case idle, busy
    case waitingInput      // Notification with notification_type=idle_prompt
    case waitingPermission // PermissionRequest event

    /// Distinct emoji used in the menu body — both waiting states still
    /// surface as 🟡 in the menu bar icon (see `menuBarEmoji`).
    var emoji: String {
        switch self {
        case .idle:              return "🟢"
        case .busy:              return "🔴"
        case .waitingInput:      return "💬"
        case .waitingPermission: return "🔒"
        }
    }

    var label: String {
        switch self {
        case .idle:              return "Idle"
        case .busy:              return "Working..."
        case .waitingInput:      return "Waiting for input"
        case .waitingPermission: return "Waiting for permission"
        }
    }

    /// Priority for the menu-bar icon and menu ordering.
    /// `waiting* > idle > busy`:
    ///   - waiting*: I need the user — show this first so they don't miss it
    ///   - idle:    nothing is happening — all clear
    ///   - busy:    Claude is working — no action needed from the user
    /// Among "no-action-needed" states, all-clear beats in-progress.
    var priority: Int {
        switch self {
        case .waitingInput, .waitingPermission: return 2
        case .idle:                             return 1
        case .busy:                             return 0
        }
    }

    /// Emoji used for the menu bar icon. Both waiting states share the
    /// same yellow light; the dropdown distinguishes them via `emoji`.
    var menuBarEmoji: String {
        switch self {
        case .waitingInput, .waitingPermission: return "🟡"
        default: return emoji
        }
    }
}

struct SessionState: Codable {
    let state: CCState
    let session_id: String?
    let cwd: String?
    let transcript_path: String?
    let ts: Int?

    var id: String { session_id ?? "_default" }
    var shortId: String { String((session_id ?? "default").prefix(8)) }

    /// Last path component of cwd, or "(no cwd)" if missing.
    var projectName: String {
        guard let cwd = cwd, !cwd.isEmpty else { return "(no cwd)" }
        return (cwd as NSString).lastPathComponent
    }

    /// Background sessions run on their own schedule and churn busy↔idle
    /// every few seconds (e.g. claude-mem's observer wakes ~every 20s,
    /// fires a single PreToolUse → busy then Stop → idle within the same
    /// second). Their "idle" is the normal state, not an actionable
    /// signal the user should respond to. They show in their own menu
    /// section but are excluded from the menu-bar icon aggregation —
    /// otherwise they'd drag the icon green every ~20s and mask whatever
    /// the foreground project sessions are actually doing.
    ///
    /// Matched by substring on cwd. Add a new pattern here if another
    /// background-session type appears.
    var isBackground: Bool {
        guard let cwd = cwd, !cwd.isEmpty else { return false }
        return SessionState.backgroundCwdPatterns.contains { cwd.contains($0) }
    }

    private static let backgroundCwdPatterns: [String] = [
        ".claude-mem/observer-sessions",
    ]
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var timer: Timer?
    var sessions: [SessionState] = []
    let stateDir = "/tmp/cc-light"
    /// Sessions whose `ts` is older than this are treated as gone.
    /// Set to 5 minutes: pure thinking / long text generation in
    /// Claude Code is a black box to hooks (no event fires during
    /// model output), so the busy state needs to survive the gap.
    /// 30s — the previous value — caused sessions to drop out of the
    /// menu while Claude was still visibly working ("thinking",
    /// "generating", "incubating", etc.).
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
            // Waiting states are exempt from stale filtering — they mean
            // "Claude is sitting idle waiting for you to act", which is
            // only useful while still visible. Idle/busy still expire
            // after `staleThreshold` to clear crashed sessions.
            if s.state != .waitingInput && s.state != .waitingPermission,
               let ts = s.ts,
               now.timeIntervalSince(Date(timeIntervalSince1970: Double(ts))) > staleThreshold {
                continue
            }
            results.append(s)
        }

        // Highest-priority state first (waiting > idle > busy), then by
        // project name for stable ordering.
        sessions = results.sorted {
            if $0.state.priority != $1.state.priority { return $0.state.priority > $1.state.priority }
            return $0.projectName < $1.projectName
        }

        // Aggregate: pick the highest-priority state across all *foreground*
        // sessions. Background sessions (see SessionState.isBackground) are
        // intentionally excluded — they cycle idle every ~20s and would
        // otherwise drag the icon green whenever they happen to be in their
        // idle phase, masking what the actual project sessions are doing.
        // Empty → idle (green). All busy → busy (red). Any waiting* → yellow.
        let agg: CCState = sessions
            .filter { !$0.isBackground }
            .map { $0.state }
            .max(by: { $0.priority < $1.priority }) ?? .idle

        DispatchQueue.main.async {
            self.statusItem.button?.title = agg.menuBarEmoji
            self.updateMenu()
        }
    }

    func updateMenu() {
        let menu = NSMenu()

        // App identity header. Disabled (greyed) so it's clearly a label,
        // not a clickable row. Bold weight sets it apart from session
        // entries below.
        let header = NSMenuItem(title: "CC Light", action: nil, keyEquivalent: "")
        header.isEnabled = false
        let headerFont = NSFontManager.shared.font(withFamily: ".AppleSystemUIFont", traits: .boldFontMask, weight: 6, size: 13)
        if let font = headerFont {
            header.attributedTitle = NSAttributedString(
                string: "CC Light",
                attributes: [.font: font]
            )
        }
        menu.addItem(header)
        menu.addItem(.separator())

        if sessions.isEmpty {
            menu.addItem(NSMenuItem(title: "No active sessions", action: nil, keyEquivalent: ""))
        } else {
            // Four sections, top-down:
            //   1. waiting-for-permission  — most urgent (locks you out of work)
            //   2. waiting-for-input       — Claude is idle, needs your prompt
            //   3. busy/idle foreground    — your actual project sessions
            //   4. background              — claude-mem observer & friends;
            //                                excluded from the icon aggregation
            //                                so their constant idle churn doesn't
            //                                drag the menu bar green
            let waitingPermission = sessions.filter { $0.state == .waitingPermission }
            let waitingInput      = sessions.filter { $0.state == .waitingInput }
            let foregroundOthers  = sessions.filter {
                $0.state != .waitingPermission && $0.state != .waitingInput
                    && !$0.isBackground
            }
            let background        = sessions.filter { $0.isBackground }

            func addSection(_ items: [SessionState], header: String, renderEmoji: Bool) {
                guard !items.isEmpty else { return }
                let h = NSMenuItem(title: header, action: nil, keyEquivalent: "")
                h.isEnabled = false
                menu.addItem(h)
                for s in items {
                    let glyph = renderEmoji ? s.state.emoji : ""
                    let title = glyph.isEmpty
                        ? "\(s.projectName)  —  \(s.shortId)"
                        : "\(glyph)  \(s.projectName)  —  \(s.shortId)"
                    menu.addItem(NSMenuItem(title: title, action: nil, keyEquivalent: ""))
                }
                menu.addItem(.separator())
            }

            addSection(waitingPermission,
                       header: "\(waitingPermission.count) waiting for permission",
                       renderEmoji: true)
            addSection(waitingInput,
                       header: "\(waitingInput.count) waiting for input",
                       renderEmoji: true)

            if !foregroundOthers.isEmpty {
                let busyCount = foregroundOthers.filter { $0.state == .busy }.count
                let idleCount = foregroundOthers.filter { $0.state == .idle }.count
                addSection(foregroundOthers,
                           header: "\(busyCount) busy · \(idleCount) idle",
                           renderEmoji: true)
            }

            // Background section last, with an explicit "ignored" note so
            // it's clear these don't affect the menu-bar icon color.
            if !background.isEmpty {
                addSection(background,
                           header: "\(background.count) background · ignored",
                           renderEmoji: true)
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
