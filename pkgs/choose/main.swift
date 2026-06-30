import SwiftUI
import AppKit

// MARK: - Data Types

enum ItemKind {
    case plain     // generic item from stdin (utility menus): client interprets it
    case command   // launcher command: selecting returns its id to the client
    case app       // launcher app: the daemon launches it natively
}

struct ItemAction {
    let key: String      // "enter", "cmd", "opt", "ctrl"
    let label: String

    var displayKey: String {
        switch key {
        case "enter": return "↵"
        case "cmd": return "⌘↵"
        case "opt": return "⌥↵"
        case "ctrl": return "⌃↵"
        default: return key
        }
    }
}

struct ChooseItem: Identifiable {
    let id = UUID()
    let raw: String
    let title: String
    let subtitle: String?
    let icon: String?
    let actions: [ItemAction]
    let kind: ItemKind
    let payload: String       // cmd id (command) / bundle path (app) / raw (plain)
    let frecencyKey: String   // stable key for usage history
    let baseBoost: Double     // recency boost for freshly-installed apps

    // Generic stdin line: title \t subtitle \t icon \t actions
    static func parsePlain(_ line: String, globalIcon: String?) -> ChooseItem {
        let parts = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
        let title = parts.count > 0 ? parts[0] : line
        let subtitle = parts.count > 1 && !parts[1].isEmpty ? parts[1] : nil
        let icon = (parts.count > 2 && !parts[2].isEmpty ? parts[2] : nil) ?? globalIcon

        var actions: [ItemAction] = []
        if parts.count > 3 && !parts[3].isEmpty {
            let actionParts = parts[3].split(separator: "|").map(String.init)
            for (index, part) in actionParts.enumerated() {
                if index == 0 {
                    actions.append(ItemAction(key: "enter", label: part))
                } else if part.contains(":") {
                    let kv = part.split(separator: ":", maxSplits: 1).map(String.init)
                    if kv.count == 2 { actions.append(ItemAction(key: kv[0], label: kv[1])) }
                }
            }
        }
        if actions.isEmpty { actions.append(ItemAction(key: "enter", label: "Select")) }

        return ChooseItem(raw: line, title: title, subtitle: subtitle, icon: icon,
                          actions: actions, kind: .plain, payload: line,
                          frecencyKey: title, baseBoost: 0)
    }

    // Launcher command registry line: name \t description \t icon \t id
    static func parseCommand(_ line: String) -> ChooseItem {
        let parts = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
        let title = parts.count > 0 ? parts[0] : line
        let subtitle = parts.count > 1 && !parts[1].isEmpty ? parts[1] : nil
        let icon = parts.count > 2 && !parts[2].isEmpty ? parts[2] : "sparkles"
        let id = parts.count > 3 ? parts[3] : title
        return ChooseItem(raw: line, title: title, subtitle: subtitle, icon: icon,
                          actions: [ItemAction(key: "enter", label: "Run")],
                          kind: .command, payload: id,
                          frecencyKey: "cmd:\(id)", baseBoost: 0)
    }

    static func app(name: String, path: String, boost: Double) -> ChooseItem {
        return ChooseItem(raw: path, title: name, subtitle: "Application",
                          icon: "app:\(path)",
                          actions: [ItemAction(key: "enter", label: "Open"),
                                    ItemAction(key: "cmd", label: "Reveal in Finder")],
                          kind: .app, payload: path,
                          frecencyKey: "app:\(path)", baseBoost: boost)
    }

    func action(for key: String) -> ItemAction? { actions.first { $0.key == key } }
}

// MARK: - Fuzzy Matching

enum Fuzzy {
    // Subsequence match with quality scoring. Returns nil if `query` is not a
    // subsequence of `target`. Higher = tighter / earlier / word-boundary match.
    static func score(_ query: [Character], _ target: String) -> Double? {
        let t = Array(target)
        guard !query.isEmpty else { return 0 }
        var qi = 0
        var score = 0.0
        var prevMatch = -2
        var firstIdx = -1

        for (ti, ch) in t.enumerated() {
            guard qi < query.count, ch == query[qi] else { continue }
            if firstIdx < 0 { firstIdx = ti }
            var s = 1.0
            if ti == prevMatch + 1 { s += 2.5 }                    // consecutive run
            if ti == 0 { s += 2.0 }                                // very start
            else {
                let p = t[ti - 1]
                if p == " " || p == "-" || p == "_" || p == "." { s += 1.5 } // word boundary
            }
            score += s
            prevMatch = ti
            qi += 1
        }
        guard qi == query.count else { return nil }

        // Reward tight targets and front-loaded matches.
        let coverage = Double(query.count) / Double(max(t.count, 1))
        let frontBonus = firstIdx == 0 ? 1.5 : 0
        return score + coverage * 2.0 + frontBonus
    }
}

// MARK: - App Scanner

final class AppScanner {
    static let shared = AppScanner()

    private struct Meta { let name: String; let ctime: Double }
    private var cache: [String: Meta] = [:]          // path -> metadata
    private let lock = NSLock()

    private let searchDirs: [URL] = {
        var dirs = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            URL(fileURLWithPath: "/System/Applications/Utilities"),
        ]
        dirs.append(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications"))
        return dirs
    }()

    // Boost freshly-installed apps so they surface at the top, decaying over a week.
    private func boost(forAge age: Double) -> Double {
        let week = 7.0 * 86400
        guard age >= 0, age < week else { return 0 }
        let halfLife = 2.0 * 86400
        return 1000.0 * exp(-log(2.0) / halfLife * age)
    }

    func apps() -> [ChooseItem] {
        let fm = FileManager.default
        let now = Date().timeIntervalSince1970
        var seen = Set<String>()
        var result: [ChooseItem] = []

        lock.lock(); defer { lock.unlock() }

        for dir in searchDirs {
            let keys: [URLResourceKey] = [.isDirectoryKey, .creationDateKey]
            guard let en = fm.enumerator(at: dir, includingPropertiesForKeys: keys,
                                         options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { continue }
            while let url = en.nextObject() as? URL {
                guard url.pathExtension == "app" else { continue }
                let path = url.path
                if seen.contains(path) { continue }
                seen.insert(path)

                let ctime = (try? url.resourceValues(forKeys: [.creationDateKey]))?
                    .creationDate?.timeIntervalSince1970 ?? 0

                let name: String
                if let m = cache[path], m.ctime == ctime {
                    name = m.name
                } else {
                    name = displayName(for: url)
                    cache[path] = Meta(name: name, ctime: ctime)
                }
                result.append(.app(name: name, path: path, boost: boost(forAge: now - ctime)))
            }
        }
        return result
    }

    private func displayName(for url: URL) -> String {
        if let info = Bundle(url: url)?.infoDictionary {
            if let n = info["CFBundleDisplayName"] as? String, !n.isEmpty { return n }
            if let n = info["CFBundleName"] as? String, !n.isEmpty { return n }
        }
        return url.deletingPathExtension().lastPathComponent
    }

    // Warm the cache off the main thread at startup.
    func warm() {
        DispatchQueue.global(qos: .utility).async { _ = self.apps() }
    }
}

// MARK: - Frecency

final class Frecency {
    struct Entry: Codable { var count: Int; var lastUsed: Double }

    private var data: [String: Entry] = [:]
    private let path: URL
    private let lambda: Double

    init() {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/share/choose")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.path = dir.appendingPathComponent("frecency.json")
        self.lambda = log(2.0) / (72 * 3600)
        load()
    }

    private func load() {
        guard let raw = try? Data(contentsOf: path),
              let decoded = try? JSONDecoder().decode([String: Entry].self, from: raw) else { return }
        data = decoded
    }

    private func save() {
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        try? encoded.write(to: path, options: .atomic)
    }

    func score(for key: String) -> Double {
        guard let entry = data[key] else { return 0 }
        let age = Date().timeIntervalSince1970 - entry.lastUsed
        return Double(entry.count) * exp(-lambda * age)
    }

    func record(_ key: String) {
        var entry = data[key] ?? Entry(count: 0, lastUsed: 0)
        entry.count += 1
        entry.lastUsed = Date().timeIntervalSince1970
        data[key] = entry
        save()
    }
}

// MARK: - Commit

enum Disposition { case hideNow, linger }

struct Commit {
    let clientString: String?               // sent back to the connected client (nil → "")
    let disposition: Disposition
    let appLaunch: (path: String, reveal: Bool)?
}

// MARK: - State

final class DaemonState: ObservableObject {
    @Published var items: [ChooseItem] = []
    @Published var itemsSorted: [ChooseItem] = []   // empty-query order
    @Published var placeholderText: String = "Search..."
    @Published var globalIcon: String? = nil
    @Published var isVisible: Bool = false
    @Published var requestID = UUID()
    @Published var metrics: LayoutMetrics = .standard

    var isLauncher = false
    var maxEmpty = Int.max

    let frecency = Frecency()
    private var frecencyScores: [UUID: Double] = [:]

    var onCommit: ((Commit) -> Void)?
    var onResize: (() -> Void)?       // content height changed; window should refit
    weak var textField: NSTextField?

    func reset() {
        items = []
        itemsSorted = []
        frecencyScores = [:]
        placeholderText = "Search..."
        globalIcon = nil
        isLauncher = false
        maxEmpty = Int.max
        requestID = UUID()
    }

    func load(lines: [String], placeholder: String?, icon: String?, launcher: Bool, maxEmpty: Int?) {
        globalIcon = icon
        isLauncher = launcher
        self.maxEmpty = maxEmpty ?? (launcher ? 7 : Int.max)

        var built: [ChooseItem] = []
        if launcher {
            built.append(contentsOf: lines.filter { !$0.isEmpty }.map { ChooseItem.parseCommand($0) })
            built.append(contentsOf: AppScanner.shared.apps())
            placeholderText = placeholder ?? "Search apps & actions..."
        } else {
            built = lines.map { ChooseItem.parsePlain($0, globalIcon: icon) }
            placeholderText = placeholder ?? (lines.isEmpty ? "Input..." : "Search...")
        }
        items = built
        frecencyScores = Dictionary(uniqueKeysWithValues: built.map { ($0.id, frecency.score(for: $0.frecencyKey)) })

        itemsSorted = built.sorted { a, b in
            (frecencyScores[a.id] ?? 0) + a.baseBoost > (frecencyScores[b.id] ?? 0) + b.baseBoost
        }
    }

    private func frecency(for item: ChooseItem) -> Double { frecencyScores[item.id] ?? 0 }

    // Combined relevance for a typed query. nil → no match.
    func matchScore(_ item: ChooseItem, query: [Character]) -> Double? {
        let title = Fuzzy.score(query, item.title.lowercased())
        let sub = item.subtitle.flatMap { Fuzzy.score(query, $0.lowercased()) }
        let candidates = [title, sub.map { $0 * 0.5 }].compactMap { $0 }
        guard let best = candidates.max() else { return nil }
        let frec = frecency(for: item)
        let normFrec = frec / (frec + 5)                 // 0..1
        let boost = item.baseBoost > 0 ? 0.8 : 0
        return best + normFrec * 1.5 + boost
    }

    func commit(_ item: ChooseItem, action: String) {
        frecency.record(item.frecencyKey)
        onCommit?(buildCommit(item, action: action))
    }

    func commitText(_ text: String) {
        onCommit?(Commit(clientString: "enter\t\(text)", disposition: .linger, appLaunch: nil))
    }

    func cancel() {
        onCommit?(Commit(clientString: "", disposition: .hideNow, appLaunch: nil))
    }

    private func buildCommit(_ item: ChooseItem, action: String) -> Commit {
        switch item.kind {
        case .app:
            return Commit(clientString: "", disposition: .hideNow,
                          appLaunch: (item.payload, action == "cmd"))
        case .command:
            return Commit(clientString: "run\t\(item.payload)", disposition: .linger, appLaunch: nil)
        case .plain:
            let a = item.action(for: action) != nil ? action : "enter"
            return Commit(clientString: "\(a)\t\(item.raw)", disposition: .linger, appLaunch: nil)
        }
    }
}

// MARK: - Socket Path

enum SocketConfig {
    static let dir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".local/share/choose").path
    static let path = dir + "/choose.sock"
}

// MARK: - Settings & Layout

// Layout dimensions for a given window mode. The window resizes to `width` and
// the list/header shrink with the other fields, so "compact" reads as a tighter
// Raycast-style launcher.
struct LayoutMetrics {
    let width: CGFloat
    let rowHeight: CGFloat
    let maxVisibleItems: Int
    let headerHeight: CGFloat
    let searchIconSize: CGFloat
    let searchFontSize: CGFloat
    let topInsetFraction: CGFloat   // distance from top of screen, as a fraction of height

    static let standard = LayoutMetrics(
        width: 720, rowHeight: 46, maxVisibleItems: 8, headerHeight: 60,
        searchIconSize: 18, searchFontSize: 20, topInsetFraction: 0.16)

    static let compact = LayoutMetrics(
        width: 600, rowHeight: 42, maxVisibleItems: 6, headerHeight: 52,
        searchIconSize: 16, searchFontSize: 18, topInsetFraction: 0.20)
}

// User settings, read from ~/.config/choose/config.json. Parsed leniently via
// JSONSerialization so unknown/extra keys (added by future versions) never break
// an older binary, and any missing/malformed value falls back to a default.
struct Settings {
    enum WindowMode: String { case standard = "default", compact }

    var windowMode: WindowMode = .standard

    var metrics: LayoutMetrics {
        switch windowMode {
        case .standard: return .standard
        case .compact: return .compact
        }
    }

    static var configPath: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/choose/config.json")
    }

    // Cheap enough (tiny file) to re-read per invocation, so edits take effect
    // on the next open without restarting the daemon.
    static func load() -> Settings {
        var s = Settings()
        guard let data = try? Data(contentsOf: configPath),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return s }
        if let wm = obj["windowMode"] as? String, let mode = WindowMode(rawValue: wm) {
            s.windowMode = mode
        }
        return s
    }
}

// MARK: - Window

class ChooseWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - ChooseUI (window controller shared by daemon + direct mode)

final class ChooseUI {
    let window: ChooseWindow
    let hosting: NSHostingView<ContentView>
    let state: DaemonState

    private var lingerItem: DispatchWorkItem?
    var resultSink: ((String) -> Void)?

    init(state: DaemonState) {
        self.state = state
        self.hosting = NSHostingView(rootView: ContentView(state: state))

        window = ChooseWindow(
            contentRect: NSRect(x: 0, y: 0, width: LayoutMetrics.standard.width, height: 400),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = false
        window.level = .floating
        window.hasShadow = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        let blur = NSVisualEffectView()
        blur.material = .hudWindow
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.wantsLayer = true
        blur.layer?.cornerRadius = 16
        blur.layer?.masksToBounds = true
        blur.layer?.borderWidth = 1
        blur.layer?.borderColor = NSColor.white.withAlphaComponent(0.08).cgColor
        hosting.autoresizingMask = [.width, .height]
        blur.addSubview(hosting)
        window.contentView = blur

        state.onCommit = { [weak self] commit in self?.handleCommit(commit) }
        state.onResize = { [weak self] in
            // Defer one runloop tick so SwiftUI has committed the new layout
            // before we measure its fitting height.
            DispatchQueue.main.async { self?.resizeToFit() }
        }

        NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification, object: window, queue: .main
        ) { [weak self] _ in
            guard let self = self, self.state.isVisible else { return }
            self.state.cancel()
        }
    }

    // MARK: Presentation

    func present() {
        cancelLinger()
        let fresh = !window.isVisible
        let size = hosting.fittingSize
        let target = NSSize(width: state.metrics.width, height: size.height)

        if fresh {
            window.setContentSize(target)
            positionFresh(size: target)
        } else {
            // Keep the top edge anchored so the list grows/shrinks downward.
            let oldTop = window.frame.maxY
            window.setContentSize(target)
            var f = window.frame
            f.origin.y = oldTop - f.height
            if let vf = (window.screen ?? NSScreen.main)?.visibleFrame {
                f.origin.x = vf.midX - f.width / 2
            }
            window.setFrame(f, display: true)
        }
        hosting.frame = window.contentView?.bounds ?? .zero
        window.alphaValue = 1
        state.isVisible = true

        window.makeKeyAndOrderFront(nil)
        if fresh { NSApp.activate(ignoringOtherApps: true) }
        if let tf = state.textField { window.makeFirstResponder(tf) }

        // Correct the height once SwiftUI has laid out the freshly-loaded items
        // (fittingSize above can lag the @Published change by a tick).
        DispatchQueue.main.async { [weak self] in self?.resizeToFit() }
    }

    // Match the window height to the SwiftUI content, anchoring the top edge so
    // the list grows/shrinks downward as the query filters it.
    func resizeToFit() {
        guard window.isVisible else { return }
        let h = hosting.fittingSize.height
        guard h > 1, abs(h - window.frame.height) > 0.5 else { return }
        let oldTop = window.frame.maxY
        var f = window.frame
        f.size.height = h
        f.size.width = state.metrics.width
        f.origin.y = oldTop - h
        window.setFrame(f, display: true)
        hosting.frame = window.contentView?.bounds ?? .zero
    }

    private func positionFresh(size: NSSize) {
        guard let vf = (NSScreen.main ?? window.screen)?.visibleFrame else { window.center(); return }
        let x = vf.midX - size.width / 2
        let topInset = vf.height * state.metrics.topInsetFraction
        let y = vf.maxY - topInset - size.height
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    // MARK: Commit handling

    private func handleCommit(_ commit: Commit) {
        state.isVisible = false

        if let app = commit.appLaunch {
            let url = URL(fileURLWithPath: app.path)
            if app.reveal {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } else {
                let cfg = NSWorkspace.OpenConfiguration()
                cfg.activates = true
                NSWorkspace.shared.openApplication(at: url, configuration: cfg)
            }
        }

        resultSink?(commit.clientString ?? "")

        switch commit.disposition {
        case .hideNow: hideNow()
        case .linger: startLinger()
        }
    }

    // MARK: Hide / linger

    func hideNow() {
        cancelLinger()
        window.orderOut(nil)
    }

    private func startLinger() {
        cancelLinger()
        let work = DispatchWorkItem { [weak self] in self?.fadeOut() }
        lingerItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    private func cancelLinger() {
        lingerItem?.cancel()
        lingerItem = nil
    }

    private func fadeOut() {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.12
            window.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.window.orderOut(nil)
            self?.window.alphaValue = 1
        })
    }
}

// MARK: - Entry Point

@main
enum Main {
    static func main() {
        if CommandLine.arguments.contains("--daemon") {
            DaemonMode.run()
        } else {
            ClientMode.run()
        }
    }
}

// MARK: - Argument / Config Parsing

struct Invocation {
    var placeholder: String?
    var icon: String?
    var launcher = false
    var maxEmpty: Int?
}

// MARK: - Daemon Mode

enum DaemonMode {
    static func run() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        let state = DaemonState()
        let ui = ChooseUI(state: state)
        ui.window.orderOut(nil)

        AppScanner.shared.warm()

        let cleanupAndExit: @convention(c) (Int32) -> Void = { _ in
            unlink(SocketConfig.path); _exit(0)
        }
        signal(SIGTERM, cleanupAndExit)
        signal(SIGINT, cleanupAndExit)

        DispatchQueue.global(qos: .userInitiated).async {
            startSocketServer(state: state, ui: ui)
        }

        NSLog("choose daemon started, listening on \(SocketConfig.path)")
        app.run()
    }

    static func startSocketServer(state: DaemonState, ui: ChooseUI) {
        unlink(SocketConfig.path)
        try? FileManager.default.createDirectory(atPath: SocketConfig.dir,
                                                 withIntermediateDirectories: true)

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { NSLog("choose daemon: failed to create socket"); return }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            SocketConfig.path.withCString { cstr in
                _ = memcpy(ptr, cstr, min(strlen(cstr) + 1, MemoryLayout.size(ofValue: ptr.pointee)))
            }
        }
        let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)
        guard withUnsafePointer(to: &addr, { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, addrLen) }
        }) == 0 else { NSLog("choose daemon: failed to bind socket"); close(fd); return }

        guard listen(fd, 5) == 0 else { NSLog("choose daemon: failed to listen"); close(fd); return }

        while true {
            var clientAddr = sockaddr_un()
            var clientLen = socklen_t(MemoryLayout<sockaddr_un>.size)
            let clientFD = withUnsafeMutablePointer(to: &clientAddr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { accept(fd, $0, &clientLen) }
            }
            guard clientFD >= 0 else { continue }
            handleClient(clientFD: clientFD, state: state, ui: ui)
        }
    }

    static func handleClient(clientFD: Int32, state: DaemonState, ui: ChooseUI) {
        var data = Data()
        var buf = [UInt8](repeating: 0, count: 65536)
        while true {
            let n = read(clientFD, &buf, buf.count)
            if n <= 0 { break }
            data.append(contentsOf: buf[0..<n])
        }
        guard let payload = String(data: data, encoding: .utf8), !payload.isEmpty else {
            close(clientFD); return
        }

        var lines = payload.components(separatedBy: "\n")
        if lines.last == "" { lines.removeLast() }

        var inv = Invocation()
        var itemLines: [String] = lines
        if let first = lines.first, first.hasPrefix("CONFIG\t") {
            let p = first.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            if p.count > 1 && !p[1].isEmpty { inv.placeholder = p[1] }
            if p.count > 2 && !p[2].isEmpty { inv.icon = p[2] }
            if p.count > 3 && p[3] == "launcher" { inv.launcher = true }
            if p.count > 4, let m = Int(p[4]) { inv.maxEmpty = m }
            itemLines = Array(lines.dropFirst())
        }

        let semaphore = DispatchSemaphore(value: 0)
        var result = ""
        let metrics = Settings.load().metrics   // re-read per request so edits apply live

        DispatchQueue.main.async {
            state.reset()
            state.metrics = metrics
            state.load(lines: itemLines, placeholder: inv.placeholder, icon: inv.icon,
                       launcher: inv.launcher, maxEmpty: inv.maxEmpty)
            ui.resultSink = { r in result = r; semaphore.signal() }
            ui.present()
        }

        semaphore.wait()

        if !result.isEmpty {
            let resultData = (result + "\n").data(using: .utf8)!
            resultData.withUnsafeBytes { ptr in _ = write(clientFD, ptr.baseAddress!, resultData.count) }
        }
        close(clientFD)
    }
}

// MARK: - Client Mode

enum ClientMode {
    static func parseArgs() -> Invocation {
        var inv = Invocation()
        var args = Array(CommandLine.arguments.dropFirst())
        while !args.isEmpty {
            let arg = args.removeFirst()
            switch arg {
            case "-p", "--placeholder": if !args.isEmpty { inv.placeholder = args.removeFirst() }
            case "-i", "--icon":        if !args.isEmpty { inv.icon = args.removeFirst() }
            case "--launcher":          inv.launcher = true
            case "--max-empty":         if !args.isEmpty { inv.maxEmpty = Int(args.removeFirst()) }
            default: break
            }
        }
        return inv
    }

    static func run() {
        var stdinLines: [String] = []
        if isatty(FileHandle.standardInput.fileDescriptor) == 0 {
            while let line = readLine() { stdinLines.append(line) }
        }
        let inv = parseArgs()

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { runDirect(lines: stdinLines, inv: inv); return }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            SocketConfig.path.withCString { cstr in
                _ = memcpy(ptr, cstr, min(strlen(cstr) + 1, MemoryLayout.size(ofValue: ptr.pointee)))
            }
        }
        let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)
        let connected = withUnsafePointer(to: &addr, { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, addrLen) }
        }) == 0
        if !connected { close(fd); runDirect(lines: stdinLines, inv: inv); return }

        let mode = inv.launcher ? "launcher" : ""
        let maxEmpty = inv.maxEmpty.map(String.init) ?? ""
        var payload = "CONFIG\t\(inv.placeholder ?? "")\t\(inv.icon ?? "")\t\(mode)\t\(maxEmpty)\n"
        for line in stdinLines { payload += line + "\n" }

        if let data = payload.data(using: .utf8) {
            data.withUnsafeBytes { ptr in _ = write(fd, ptr.baseAddress!, data.count) }
        }
        shutdown(fd, SHUT_WR)

        var resultData = Data()
        var buf = [UInt8](repeating: 0, count: 4096)
        while true {
            let n = read(fd, &buf, buf.count)
            if n <= 0 { break }
            resultData.append(contentsOf: buf[0..<n])
        }
        close(fd)

        if let result = String(data: resultData, encoding: .utf8)?.trimmingCharacters(in: .newlines),
           !result.isEmpty {
            print(result); exit(0)
        } else {
            exit(1)
        }
    }

    // Fallback when the daemon is not running.
    static func runDirect(lines: [String], inv: Invocation) {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        let state = DaemonState()
        let ui = ChooseUI(state: state)
        state.metrics = Settings.load().metrics
        state.load(lines: lines, placeholder: inv.placeholder, icon: inv.icon,
                   launcher: inv.launcher, maxEmpty: inv.maxEmpty)

        ui.resultSink = { result in
            if result.isEmpty { exit(1) }
            print(result); NSApp.terminate(nil)
        }
        DispatchQueue.main.async { ui.present() }
        app.run()
    }
}

// MARK: - Theme

enum Theme {
    static let base = Color(hex: "1e1e2e")
    static let surface0 = Color(hex: "313244")
    static let surface1 = Color(hex: "45475a")
    static let surface2 = Color(hex: "585b70")
    static let text = Color(hex: "cdd6f4")
    static let subtext = Color(hex: "a6adc8")
    static let subtext0 = Color(hex: "6c7086")
    static let mauve = Color(hex: "cba6f7")
    static let blue = Color(hex: "89b4fa")
}

// MARK: - ContentView

struct ContentView: View {
    @ObservedObject var state: DaemonState
    @State private var query = ""
    @State private var selectedIndex = 0

    var rowHeight: CGFloat { state.metrics.rowHeight }
    var maxVisibleItems: Int { state.metrics.maxVisibleItems }

    var filtered: [ChooseItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return Array(state.itemsSorted.prefix(state.maxEmpty))
        }
        let q = Array(trimmed.lowercased())
        let scored = state.items.compactMap { item -> (ChooseItem, Double)? in
            guard let s = state.matchScore(item, query: q) else { return nil }
            return (item, s)
        }
        return scored.sorted { $0.1 > $1.1 }.map { $0.0 }
    }

    var selectedItem: ChooseItem? {
        guard selectedIndex < filtered.count else { return nil }
        return filtered[selectedIndex]
    }

    var listHeight: CGFloat {
        CGFloat(min(filtered.count, maxVisibleItems)) * rowHeight
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search header
            HStack(spacing: 12) {
                Image(systemName: state.globalIcon ?? "magnifyingglass")
                    .font(.system(size: state.metrics.searchIconSize, weight: .medium))
                    .foregroundColor(Theme.subtext)
                CustomTextField(
                    text: $query,
                    selectedIndex: $selectedIndex,
                    itemCount: filtered.count,
                    placeholder: state.placeholderText,
                    fontSize: state.metrics.searchFontSize,
                    state: state,
                    onSubmit: { action in select(action: action) }
                )
            }
            .padding(.horizontal, 20)
            .frame(height: state.metrics.headerHeight)

            if !filtered.isEmpty {
                Divider().background(Theme.surface1.opacity(0.5))

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(filtered.enumerated()), id: \.element.id) { i, item in
                                ItemRow(item: item, isSelected: i == selectedIndex)
                                    .frame(height: rowHeight)
                                    .id(item.id)
                                    .onTapGesture { selectedIndex = i; select(action: "enter") }
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .frame(height: listHeight + 12)
                    .onChange(of: selectedIndex) {
                        if selectedIndex < filtered.count { proxy.scrollTo(filtered[selectedIndex].id) }
                    }
                }

                if let item = selectedItem {
                    Divider().background(Theme.surface1.opacity(0.5))
                    ActionBar(actions: item.actions)
                        .frame(height: 44)
                }
            }
        }
        .frame(width: state.metrics.width)
        .fixedSize(horizontal: false, vertical: true)
        .background(Theme.base.opacity(0.55))
        .onChange(of: query) { selectedIndex = 0 }
        .onChange(of: filtered.count) { state.onResize?() }
        .onChange(of: state.requestID) { query = ""; selectedIndex = 0; state.onResize?() }
    }

    func select(action: String) {
        if filtered.isEmpty {
            if !query.isEmpty { state.commitText(query) } else { state.cancel() }
            return
        }
        guard selectedIndex < filtered.count else { state.cancel(); return }
        state.commit(filtered[selectedIndex], action: action)
    }
}

// MARK: - ItemRow

struct ItemRow: View {
    let item: ChooseItem
    let isSelected: Bool

    private var appIconPath: String? {
        guard let icon = item.icon, icon.hasPrefix("app:") else { return nil }
        return String(icon.dropFirst(4))
    }

    var body: some View {
        HStack(spacing: 14) {
            Group {
                if let path = appIconPath {
                    Image(nsImage: AppIconCache.shared.icon(for: path))
                        .resizable().aspectRatio(contentMode: .fit)
                } else if let iconName = item.icon {
                    Image(systemName: iconName)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(isSelected ? Theme.mauve : Theme.subtext)
                }
            }
            .frame(width: 26, height: 26)

            Text(item.title)
                .foregroundColor(Theme.text)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .lineLimit(1)

            Spacer(minLength: 8)

            if let subtitle = item.subtitle {
                Text(subtitle)
                    .foregroundColor(Theme.subtext0)
                    .font(.system(size: 13, design: .rounded))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Theme.mauve.opacity(0.20) : Color.clear)
                .padding(.horizontal, 8)
        )
        .contentShape(Rectangle())
    }
}

// MARK: - App Icon Cache

final class AppIconCache {
    static let shared = AppIconCache()
    private let cache = NSCache<NSString, NSImage>()

    func icon(for path: String) -> NSImage {
        if let cached = cache.object(forKey: path as NSString) { return cached }
        let icon = NSWorkspace.shared.icon(forFile: path)
        cache.setObject(icon, forKey: path as NSString)
        return icon
    }
}

// MARK: - ActionBar

struct ActionBar: View {
    let actions: [ItemAction]

    var body: some View {
        HStack(spacing: 18) {
            Spacer()
            ForEach(Array(actions.enumerated()), id: \.offset) { index, action in
                HStack(spacing: 6) {
                    Text(action.label)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(Theme.subtext)
                    Text(action.displayKey)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(index == 0 ? Theme.base : Theme.text)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(index == 0 ? Theme.blue : Theme.surface2)
                        .cornerRadius(5)
                }
            }
        }
        .padding(.horizontal, 18)
    }
}

// MARK: - CustomTextField

struct CustomTextField: NSViewRepresentable {
    @Binding var text: String
    @Binding var selectedIndex: Int
    let itemCount: Int
    let placeholder: String
    let fontSize: CGFloat
    let state: DaemonState
    let onSubmit: (String) -> Void

    func makeNSView(context: Context) -> NSTextField {
        let tf = NSTextField()
        tf.delegate = context.coordinator
        tf.font = NSFont.systemFont(ofSize: fontSize, weight: .regular)
        tf.textColor = NSColor(Theme.text)
        tf.backgroundColor = .clear
        tf.focusRingType = .none
        tf.isBordered = false
        tf.drawsBackground = false
        tf.placeholderString = placeholder
        tf.cell?.sendsActionOnEndEditing = false

        DispatchQueue.main.async {
            state.textField = tf
            tf.window?.makeFirstResponder(tf)
        }
        return tf
    }

    func updateNSView(_ tf: NSTextField, context: Context) {
        if tf.stringValue != text { tf.stringValue = text }
        tf.placeholderString = placeholder
        if tf.font?.pointSize != fontSize {
            tf.font = NSFont.systemFont(ofSize: fontSize, weight: .regular)
        }
        context.coordinator.itemCount = itemCount
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: CustomTextField
        var itemCount: Int

        init(_ parent: CustomTextField) {
            self.parent = parent
            self.itemCount = parent.itemCount
        }

        func controlTextDidChange(_ n: Notification) {
            if let tf = n.object as? NSTextField { parent.text = tf.stringValue }
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy sel: Selector) -> Bool {
            switch sel {
            case #selector(NSResponder.moveDown(_:)):
                if parent.selectedIndex < itemCount - 1 { parent.selectedIndex += 1 }
                return true
            case #selector(NSResponder.moveUp(_:)):
                if parent.selectedIndex > 0 { parent.selectedIndex -= 1 }
                return true
            case #selector(NSResponder.insertNewline(_:)):
                let flags = NSEvent.modifierFlags
                if flags.contains(.command) { parent.onSubmit("cmd") }
                else if flags.contains(.option) { parent.onSubmit("opt") }
                else if flags.contains(.control) { parent.onSubmit("ctrl") }
                else { parent.onSubmit("enter") }
                return true
            case #selector(NSResponder.cancelOperation(_:)):
                parent.state.cancel()
                return true
            default:
                return false
            }
        }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        self.init(red: Double((rgb >> 16) & 0xFF) / 255,
                  green: Double((rgb >> 8) & 0xFF) / 255,
                  blue: Double(rgb & 0xFF) / 255)
    }
}
