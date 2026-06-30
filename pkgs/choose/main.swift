import SwiftUI
import AppKit
import CoreText
import CoreServices
import ApplicationServices
import CoreGraphics

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
    let group: String?        // optional section header; nil → flat (ungrouped) list
    let submenu: Bool         // command re-invokes choose (two-step) → loading state

    // Generic stdin line: title \t subtitle \t icon \t actions \t group
    // The trailing `group` field is optional; when any line carries one the list
    // renders with section headers (see ContentView), otherwise it stays flat.
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

        let group = parts.count > 4 && !parts[4].isEmpty ? parts[4] : nil

        return ChooseItem(raw: line, title: title, subtitle: subtitle, icon: icon,
                          actions: actions, kind: .plain, payload: line,
                          frecencyKey: title, baseBoost: 0, group: group, submenu: false)
    }

    // Launcher command registry line: name \t description \t icon \t id \t submenu(1|0)
    static func parseCommand(_ line: String) -> ChooseItem {
        let parts = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
        let title = parts.count > 0 ? parts[0] : line
        let subtitle = parts.count > 1 && !parts[1].isEmpty ? parts[1] : nil
        let icon = parts.count > 2 && !parts[2].isEmpty ? parts[2] : "sparkles"
        let id = parts.count > 3 ? parts[3] : title
        let submenu = parts.count > 4 && parts[4] == "1"
        return ChooseItem(raw: line, title: title, subtitle: subtitle, icon: icon,
                          actions: [ItemAction(key: "enter", label: "Run")],
                          kind: .command, payload: id,
                          frecencyKey: "cmd:\(id)", baseBoost: 0, group: nil, submenu: submenu)
    }

    static func app(name: String, path: String, boost: Double) -> ChooseItem {
        return ChooseItem(raw: path, title: name, subtitle: "Application",
                          icon: "app:\(path)",
                          actions: [ItemAction(key: "enter", label: "Open"),
                                    ItemAction(key: "cmd", label: "Reveal in Finder")],
                          kind: .app, payload: path,
                          frecencyKey: "app:\(path)", baseBoost: boost, group: nil, submenu: false)
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

// hideNow: close immediately. linger: brief fade (terminal action). loading:
// keep the window up showing a spinner until the next request swaps in (a
// two-step command re-invoking choose) — never a gap between steps.
enum Disposition { case hideNow, linger, loading }

struct Commit {
    let clientString: String?               // sent back to the connected client (nil → "")
    let disposition: Disposition
    let appLaunch: (path: String, reveal: Bool)?
    // When true, after hiding the window the daemon reactivates the previously
    // focused app and synthesizes ⌘V (clipboard auto-paste). Defaults false so
    // the existing memberwise-init call sites need no change.
    var pasteAfter: Bool = false
}

// MARK: - State

enum DisplayMode { case list, clipboard, emoji, screenshots }

final class DaemonState: ObservableObject {
    @Published var items: [ChooseItem] = []
    @Published var itemsSorted: [ChooseItem] = []   // empty-query order
    @Published var placeholderText: String = "Search..."
    @Published var globalIcon: String? = nil
    @Published var isVisible: Bool = false
    @Published var requestID = UUID()
    @Published var metrics: LayoutMetrics = .standard
    @Published var displayMode: DisplayMode = .list
    @Published var clipEntries: [ClipEntry] = []
    @Published var emojiEntries: [EmojiEntry] = []
    @Published var screenshotEntries: [ScreenshotEntry] = []
    @Published var isLoading = false   // skeleton shown between a two-step command's steps
    @Published var loadingTitle = ""   // selected command's name, shown in the static header
    @Published var loadingIcon = "magnifyingglass"
    // The launcher's search text. Held here (not as ContentView @State) so reset()
    // can clear it synchronously before step 2 renders — no one-frame flash of the
    // previous query.
    @Published var query = ""

    var isLauncher = false
    var maxEmpty = Int.max

    // The clipboard and emoji views are fixed-size windows; everything else
    // follows the launcher's windowMode width.
    var targetWidth: CGFloat {
        switch displayMode {
        case .clipboard: return ClipboardLayout.width
        case .emoji: return EmojiLayout.width
        case .screenshots: return ScreenshotLayout.width
        case .list: return metrics.width
        }
    }

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
        displayMode = .list
        clipEntries = []
        emojiEntries = []
        screenshotEntries = []
        isLoading = false
        query = ""
    }

    // Load the clipboard history view from the daemon's own store.
    func loadClipboard(placeholder: String?) {
        displayMode = .clipboard
        clipEntries = ClipboardStore.shared.entries()
        placeholderText = placeholder ?? "Clipboard history…"
    }

    func commitClip(_ entry: ClipEntry) {
        ClipboardStore.shared.restore(entry)
        // Auto-paste when enabled AND we hold the Accessibility grant; otherwise
        // fall back to clipboard-only (restore already ran) and nudge once.
        var paste = false
        if Settings.load().clipboard.autoPaste {
            if AXIsProcessTrusted() {
                paste = true
            } else {
                AccessibilityHint.promptOnce()
            }
        }
        onCommit?(Commit(clientString: "", disposition: .hideNow, appLaunch: nil, pasteAfter: paste))
    }

    // Load the recent-screenshots grid from the configured screencapture folder.
    func loadScreenshots(placeholder: String?) {
        displayMode = .screenshots
        screenshotEntries = ScreenshotStore.recent()
        placeholderText = placeholder ?? "Recent screenshots…"
    }

    // Copy the selected screenshot to the clipboard as both an image (paste into
    // Slack/Notion) and a file reference (⌘V in Finder pastes the file).
    func commitScreenshot(_ entry: ScreenshotEntry) {
        Pasteboard.copyFile(URL(fileURLWithPath: entry.path))
        onCommit?(Commit(clientString: "", disposition: .hideNow, appLaunch: nil))
    }

    // Load the emoji grid from the bundled dataset.
    func loadEmoji(placeholder: String?) {
        displayMode = .emoji
        emojiEntries = EmojiStore.shared.all
        placeholderText = placeholder ?? "Search emoji…"
    }

    func emojiFrecency(_ c: String) -> Double { frecency.score(for: "emoji:\(c)") }

    // Relevance of an emoji for a typed query (name + keywords), nil → no match.
    func emojiMatch(_ e: EmojiEntry, query: [Character]) -> Double? {
        guard let s = Fuzzy.score(query, e.search) else { return nil }
        let frec = emojiFrecency(e.c)
        return s + (frec / (frec + 5)) * 1.5
    }

    // Copy the emoji to the clipboard, record frecency, and echo it to the client.
    func commitEmoji(_ e: EmojiEntry) {
        frecency.record("emoji:\(e.c)")
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(e.c, forType: .string)
        onCommit?(Commit(clientString: e.c, disposition: .hideNow, appLaunch: nil))
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
        // For a two-step command, seed the loading header with its name + icon so
        // it matches the step-2 header (which arrives with the same -p / -i).
        if item.kind == .command && item.submenu {
            loadingTitle = item.title
            loadingIcon = item.icon ?? "magnifyingglass"
        }
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
            // Two-step commands re-invoke choose → keep the window up (loading)
            // so step 2 swaps in without a gap. Terminal commands briefly linger.
            return Commit(clientString: "run\t\(item.payload)",
                          disposition: item.submenu ? .loading : .linger, appLaunch: nil)
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
// launcher.
struct LayoutMetrics {
    let width: CGFloat
    let rowHeight: CGFloat
    let maxVisibleItems: Int
    let headerHeight: CGFloat
    let searchIconSize: CGFloat
    let searchFontSize: CGFloat
    let topInsetFraction: CGFloat   // distance from top of screen, as a fraction of height
    // When true, an empty query shows no list until the user types or presses ↓
    // (the compact behaviour). When false, the empty query shows the top-N.
    let hideEmptyList: Bool

    static let standard = LayoutMetrics(
        width: 720, rowHeight: 46, maxVisibleItems: 8, headerHeight: 60,
        searchIconSize: 18, searchFontSize: 20, topInsetFraction: 0.16,
        hideEmptyList: false)

    static let compact = LayoutMetrics(
        width: 600, rowHeight: 42, maxVisibleItems: 6, headerHeight: 52,
        searchIconSize: 16, searchFontSize: 18, topInsetFraction: 0.20,
        hideEmptyList: true)
}

// Fixed geometry for the clipboard history's two-pane window (independent of the
// launcher's windowMode).
enum ClipboardLayout {
    static let width: CGFloat = 820
    static let height: CGFloat = 480
    static let listWidth: CGFloat = 300
    static let rowHeight: CGFloat = 56
}

// Fixed geometry for the emoji grid window.
enum EmojiLayout {
    static let width: CGFloat = 520
    static let columns = 9
    static let cellHeight: CGFloat = 50
    static let gridHeight: CGFloat = 320
}

// Fixed geometry for the recent-screenshots two-pane window. Mirrors the
// clipboard history layout (list on the left, large preview on the right).
enum ScreenshotLayout {
    static let width: CGFloat = 820
    static let height: CGFloat = 480
    static let listWidth: CGFloat = 300
    static let rowHeight: CGFloat = 64
}

// User settings, read from ~/.config/choose/config.json. Parsed leniently via
// JSONSerialization so unknown/extra keys (added by future versions) never break
// an older binary, and any missing/malformed value falls back to a default.
struct ClipboardSettings {
    var enabled: Bool = true
    var maxEntries: Int = 200
    // Copies whose frontmost app matches one of these bundle ids are never
    // recorded (belt-and-suspenders on top of the org.nspasteboard.ConcealedType
    // filter, which already drops password-manager copies).
    var blacklistBundleIds: [String] = ["com.apple.Passwords"]
    // Auto-paste a selected entry into the previously-focused app (synthesize ⌘V)
    // instead of only setting the clipboard. Requires the daemon to hold an
    // Accessibility grant; falls back to clipboard-only when untrusted. Default
    // off so a fresh install never silently needs a TCC permission.
    var autoPaste: Bool = false
}

struct Settings {
    enum WindowMode: String { case standard = "default", compact }

    var windowMode: WindowMode = .standard
    var clipboard = ClipboardSettings()

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
        if let cb = obj["clipboard"] as? [String: Any] {
            if let e = cb["enabled"] as? Bool { s.clipboard.enabled = e }
            if let m = cb["maxEntries"] as? Int { s.clipboard.maxEntries = m }
            if let bl = cb["blacklistBundleIds"] as? [String] { s.clipboard.blacklistBundleIds = bl }
            if let ap = cb["autoPaste"] as? Bool { s.clipboard.autoPaste = ap }
        }
        return s
    }
}

// MARK: - Pasteboard

enum Pasteboard {
    // Put a file on the clipboard with BOTH a file-URL flavor (⌘V in Finder
    // pastes the file) and image flavors (⌘V in Slack/Notion pastes the picture)
    // on a single pasteboard item, so one copy serves both paste targets.
    static func copyFile(_ url: URL) {
        let pb = NSPasteboard.general
        pb.clearContents()
        let item = NSPasteboardItem()
        item.setString(url.absoluteString, forType: .fileURL)
        if let img = NSImage(contentsOf: url), let tiff = img.tiffRepresentation {
            item.setData(tiff, forType: .tiff)
            if let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
                item.setData(png, forType: .png)
            }
        }
        pb.writeObjects([item])
    }
}

// MARK: - Auto-paste

// Synthesizes a ⌘V keystroke into whatever app is frontmost. Requires the
// process to hold an Accessibility grant (CGEvent posting is gated by TCC);
// callers must check AXIsProcessTrusted() first.
enum Paste {
    private static let kVK_ANSI_V: CGKeyCode = 0x09

    static func sendCommandV() {
        let src = CGEventSource(stateID: .combinedSessionState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: kVK_ANSI_V, keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: kVK_ANSI_V, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}

// One-time nudge when auto-paste is enabled but the daemon isn't trusted yet:
// fire the system Accessibility prompt (which deep-links to the right Settings
// pane), guarded by a marker so it never nags on every paste.
enum AccessibilityHint {
    private static var marker: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/state/choose/.autopaste-prompted")
    }

    static func promptOnce() {
        let m = marker
        if FileManager.default.fileExists(atPath: m.path) { return }
        try? FileManager.default.createDirectory(at: m.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: m.path, contents: nil)
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
    }
}

// MARK: - Screenshots

struct ScreenshotEntry: Identifiable {
    let id: String      // absolute path, also the thumbnail cache key
    let path: String
    let name: String
    let ts: Double      // file modification time (unix)
}

// Enumerates recent screenshots from the folder `screencapture` writes to.
enum ScreenshotStore {
    // Where macOS saves screenshots: the `location` default (≈ Raycast/Finder),
    // ~-expanded, falling back to ~/Desktop when unset.
    static func directory() -> URL {
        if let loc = CFPreferencesCopyAppValue("location" as CFString,
                                               "com.apple.screencapture" as CFString) as? String,
           !loc.isEmpty {
            return URL(fileURLWithPath: (loc as NSString).expandingTildeInPath)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
    }

    private static let imageExts: Set<String> = ["png", "jpg", "jpeg", "heic", "tiff", "gif", "bmp", "pdf"]

    static func recent(limit: Int = 60) -> [ScreenshotEntry] {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.contentModificationDateKey, .isRegularFileKey]
        guard let urls = try? fm.contentsOfDirectory(at: directory(),
                                                     includingPropertiesForKeys: keys,
                                                     options: [.skipsHiddenFiles]) else { return [] }
        var dated: [(ScreenshotEntry, Date)] = []
        for url in urls {
            guard imageExts.contains(url.pathExtension.lowercased()), isScreenshot(url) else { continue }
            let mod = (try? url.resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate) ?? Date(timeIntervalSince1970: 0)
            dated.append((ScreenshotEntry(id: url.path, path: url.path,
                                          name: url.lastPathComponent,
                                          ts: mod.timeIntervalSince1970), mod))
        }
        return dated.sorted { $0.1 > $1.1 }.prefix(limit).map { $0.0 }
    }

    // Spotlight's screenshot flag is locale/format-independent (unlike a filename
    // glob). Falls back to a name heuristic when the file isn't indexed yet.
    static func isScreenshot(_ url: URL) -> Bool {
        if let item = MDItemCreate(nil, url.path as CFString),
           let val = MDItemCopyAttribute(item, "kMDItemIsScreenCapture" as CFString) {
            return (val as? NSNumber)?.boolValue ?? false
        }
        let n = url.lastPathComponent.lowercased()
        return n.hasPrefix("screenshot") || n.hasPrefix("screen shot") || n.hasPrefix("cleanshot")
    }
}

// Downscaled thumbnails for the screenshot list rows, generated once and cached
// so scrolling doesn't re-decode full-resolution PNGs.
final class ThumbResolver {
    static let shared = ThumbResolver()
    private let cache = NSCache<NSString, NSImage>()

    func thumb(_ path: String) -> NSImage {
        if let c = cache.object(forKey: path as NSString) { return c }
        let target = NSSize(width: 96, height: 64)
        let thumb = NSImage(size: target)
        if let full = NSImage(contentsOfFile: path) {
            thumb.lockFocus()
            NSGraphicsContext.current?.imageInterpolation = .high
            // Aspect-fit the screenshot inside the thumbnail box.
            let s = min(target.width / max(full.size.width, 1), target.height / max(full.size.height, 1))
            let w = full.size.width * s, h = full.size.height * s
            full.draw(in: NSRect(x: (target.width - w) / 2, y: (target.height - h) / 2, width: w, height: h),
                      from: .zero, operation: .copy, fraction: 1.0)
            thumb.unlockFocus()
        }
        cache.setObject(thumb, forKey: path as NSString)
        return thumb
    }
}

// MARK: - Clipboard History

enum ClipKind: String, Codable { case text, image }

struct ClipEntry: Codable, Identifiable {
    let id: String          // uuid; also the blob filename stem
    let kind: ClipKind
    let ts: Double          // unix time captured
    let appName: String?    // frontmost app at copy time
    let bundleId: String?
    let preview: String     // one-line text snippet, or "1920 × 1080" for images
    let hash: String        // content hash, for dedup
    var width: Int?
    var height: Int?
}

// Records pasteboard history into ~/.local/share/choose/clipboard and serves it
// to the picker. Lives inside the long-running daemon, polling changeCount —
// NSPasteboard has no change notification. Reading/writing the pasteboard needs
// no special permissions.
final class ClipboardStore {
    static let shared = ClipboardStore()

    private let dir: URL
    private let blobs: URL
    private let indexURL: URL
    private let queue = DispatchQueue(label: "choose.clipboard")
    private var entriesCache: [ClipEntry] = []
    private var lastChangeCount: Int

    // de-facto nspasteboard.org markers that mean "don't record me".
    private static let skipTypes = [
        "org.nspasteboard.ConcealedType",
        "org.nspasteboard.TransientType",
        "org.nspasteboard.AutoGeneratedType",
    ].map { NSPasteboard.PasteboardType($0) }

    private init() {
        dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/share/choose/clipboard")
        blobs = dir.appendingPathComponent("blobs")
        indexURL = dir.appendingPathComponent("index.json")
        lastChangeCount = NSPasteboard.general.changeCount   // ignore whatever's already there
        try? FileManager.default.createDirectory(at: blobs, withIntermediateDirectories: true)
        load()
    }

    // MARK: Public

    func entries() -> [ClipEntry] { queue.sync { entriesCache } }

    func text(for entry: ClipEntry) -> String {
        (try? String(contentsOf: blobURL(entry, ext: "txt"), encoding: .utf8)) ?? entry.preview
    }

    func image(for entry: ClipEntry) -> NSImage? {
        NSImage(contentsOf: blobURL(entry, ext: "png"))
    }

    // Put the entry back on the system clipboard. We bump lastChangeCount past
    // our own write so the poller doesn't re-record it.
    func restore(_ entry: ClipEntry) {
        let pb = NSPasteboard.general
        pb.clearContents()
        switch entry.kind {
        case .text: pb.setString(text(for: entry), forType: .string)
        case .image: if let img = image(for: entry) { pb.writeObjects([img]) }
        }
        lastChangeCount = pb.changeCount
    }

    // Called on a timer from the daemon.
    func poll() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount
        capture(from: pb)
    }

    // MARK: Capture

    private func capture(from pb: NSPasteboard) {
        let types = Set(pb.types ?? [])
        if !Self.skipTypes.allSatisfy({ !types.contains($0) }) { return }   // concealed/transient

        let settings = Settings.load().clipboard
        let front = NSWorkspace.shared.frontmostApplication
        let bundleId = front?.bundleIdentifier
        if let b = bundleId, settings.blacklistBundleIds.contains(b) { return }
        let appName = front?.localizedName

        // Prefer non-empty text; otherwise an image.
        if let s = pb.string(forType: .string),
           !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            add(makeText(s, appName: appName, bundleId: bundleId), cap: settings.maxEntries)
        } else if let img = NSImage(pasteboard: pb),
                  let png = img.pngData() {
            add(makeImage(png, image: img, appName: appName, bundleId: bundleId),
                cap: settings.maxEntries)
        }
    }

    private func makeText(_ s: String, appName: String?, bundleId: String?) -> (ClipEntry, Data) {
        let data = Data(s.utf8)
        let snippet = s.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        let preview = String(snippet.prefix(140))
        let entry = ClipEntry(id: UUID().uuidString, kind: .text, ts: Date().timeIntervalSince1970,
                              appName: appName, bundleId: bundleId, preview: preview,
                              hash: Self.fnv1a(data), width: nil, height: nil)
        return (entry, data)
    }

    private func makeImage(_ png: Data, image: NSImage, appName: String?, bundleId: String?) -> (ClipEntry, Data) {
        let w = Int(image.size.width), h = Int(image.size.height)
        let entry = ClipEntry(id: UUID().uuidString, kind: .image, ts: Date().timeIntervalSince1970,
                              appName: appName, bundleId: bundleId, preview: "\(w) × \(h)",
                              hash: Self.fnv1a(png), width: w, height: h)
        return (entry, png)
    }

    private func add(_ made: (ClipEntry, Data), cap: Int) {
        let (entry, data) = made
        queue.sync {
            // Dedup against the most recent entry.
            if entriesCache.first?.hash == entry.hash { return }
            let ext = entry.kind == .text ? "txt" : "png"
            try? data.write(to: blobURL(entry, ext: ext), options: .atomic)
            entriesCache.insert(entry, at: 0)
            while entriesCache.count > max(cap, 1) {
                let dropped = entriesCache.removeLast()
                try? FileManager.default.removeItem(at: blobURL(dropped, ext: dropped.kind == .text ? "txt" : "png"))
            }
            save()
        }
    }

    // MARK: Persistence

    private func blobURL(_ entry: ClipEntry, ext: String) -> URL {
        blobs.appendingPathComponent("\(entry.id).\(ext)")
    }

    private func load() {
        guard let data = try? Data(contentsOf: indexURL),
              let decoded = try? JSONDecoder().decode([ClipEntry].self, from: data) else { return }
        entriesCache = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entriesCache) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }

    // Stable 64-bit FNV-1a hash (NOT Swift's per-run hashValue) so dedup works
    // across daemon restarts.
    private static func fnv1a(_ data: Data) -> String {
        var h: UInt64 = 0xcbf29ce484222325
        for b in data { h = (h ^ UInt64(b)) &* 0x100000001b3 }
        return String(h, radix: 16)
    }
}

extension NSImage {
    // PNG encoding of the image's bitmap representation.
    func pngData() -> Data? {
        guard let tiff = tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}

// MARK: - Emoji

struct EmojiEntry: Identifiable {
    let c: String          // the glyph
    let name: String
    let keywords: String
    let search: String     // precomputed "name keywords", lowercased
    var id: String { c }
}

// Loads the bundled emoji dataset (Resources/emoji.json) and filters it to the
// glyphs the running macOS can actually render. The vendored dataset is a
// superset spanning many Unicode releases; this keeps only what THIS OS draws,
// so the picker matches the installed macOS version exactly (no tofu, no
// half-supported sequences) and self-corrects on OS upgrades — no hardcoded
// version table to maintain.
final class EmojiStore {
    static let shared = EmojiStore()
    let all: [EmojiEntry]

    private init() {
        guard let url = Bundle.main.url(forResource: "emoji", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { all = []; return }

        let probeFont = NSFont(name: "Apple Color Emoji", size: 24)
        all = arr.compactMap { o -> EmojiEntry? in
            guard let c = o["c"] as? String, let n = o["n"] as? String else { return nil }
            // If the emoji font is somehow unavailable, don't filter at all.
            if let f = probeFont, !EmojiStore.renders(c, font: f) { return nil }
            let k = (o["k"] as? String) ?? ""
            return EmojiEntry(c: c, name: n, keywords: k, search: "\(n) \(k)".lowercased())
        }
    }

    // Supported on this OS == every run is still drawn by Apple Color Emoji.
    // CoreText falls back to another font for any glyph the emoji font lacks
    // (e.g. emoji newer than the installed macOS), so a fallback run means the
    // glyph isn't in this OS's set. This allows multi-glyph ligatures (gendered
    // couples, families) while dropping tofu — no Unicode-version table needed.
    private static func renders(_ s: String, font: NSFont) -> Bool {
        let attr = NSAttributedString(string: s, attributes: [.font: font])
        let line = CTLineCreateWithAttributedString(attr)
        guard let runs = CTLineGetGlyphRuns(line) as? [CTRun], !runs.isEmpty else { return false }
        for run in runs {
            let attrs = CTRunGetAttributes(run) as NSDictionary
            guard let runFont = attrs[kCTFontAttributeName as String] else { return false }
            if CTFontCopyPostScriptName(runFont as! CTFont) as String != "AppleColorEmoji" {
                return false
            }
        }
        return true
    }

    func warm() { DispatchQueue.global(qos: .utility).async { _ = EmojiStore.shared.all } }
}

// MARK: - Window

class ChooseWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - ChooseUI (window controller shared by daemon + direct mode)

final class ChooseUI {
    // A resizable rounded-rect mask: a solid rounded square with cap insets so it
    // stretches to any window size without distorting the corners.
    static func roundedMask(radius: CGFloat) -> NSImage {
        let d = radius * 2 + 1
        let image = NSImage(size: NSSize(width: d, height: d), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }

    let window: ChooseWindow
    let hosting: NSHostingView<ContentView>
    let state: DaemonState

    private var lingerItem: DispatchWorkItem?
    private var spinnerItem: DispatchWorkItem?
    var resultSink: ((String) -> Void)?

    // The app that was frontmost when the window first appeared — captured before
    // we steal focus, preserved across submenu swaps, and reactivated on an
    // auto-paste commit. Cleared when the window fully hides.
    private var capturedApp: NSRunningApplication?

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
        // layer.cornerRadius alone doesn't clip the vibrancy material or shape the
        // window shadow — a resizable rounded maskImage does both, killing the
        // square corner that pokes out behind the rounded panel.
        blur.maskImage = ChooseUI.roundedMask(radius: 16)
        // Pin the content to the TOP edge (fixed height, flexible bottom margin)
        // so an animated window resize reveals/covers from the bottom instead of
        // letting NSHostingView re-center the content and slide it vertically.
        hosting.autoresizingMask = [.width, .minYMargin]
        blur.addSubview(hosting)
        window.contentView = blur

        state.onCommit = { [weak self] commit in self?.handleCommit(commit) }
        state.onResize = { [weak self] in
            // Resize in the SAME runloop turn as the content change. Forcing
            // layout makes fittingSize current immediately, so the window and the
            // SwiftUI content never composite at mismatched sizes — that one-frame
            // mismatch (small content inside the still-tall window/blur) is the
            // flash you see when the query filters the list, worst on 0→1 letters.
            guard let self = self else { return }
            self.hosting.layoutSubtreeIfNeeded()
            self.resizeToFit()
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
        state.isLoading = false   // new content replaces any in-flight spinner
        let fresh = !window.isVisible

        if fresh {
            // Record who had focus before we steal it, so an auto-paste commit can
            // hand focus back and ⌘V into the right app. Skip our own process so a
            // stale activation can't capture choose itself.
            let front = NSWorkspace.shared.frontmostApplication
            if front?.processIdentifier != NSRunningApplication.current.processIdentifier {
                capturedApp = front
            }

            // First appear: size + position instantly (nothing to animate from).
            let size = hosting.fittingSize
            let target = NSSize(width: state.targetWidth, height: size.height)
            window.setContentSize(target)
            positionFresh(size: target)
            hosting.frame = window.contentView?.bounds ?? .zero
        }
        // Non-fresh (window already up, e.g. swapping in step 2 after the skeleton):
        // leave the current size and let the deferred resizeToFit tween to the new
        // content height, so the step transition animates instead of snapping.

        window.alphaValue = 1
        state.isVisible = true

        window.makeKeyAndOrderFront(nil)
        if fresh { NSApp.activate(ignoringOtherApps: true) }
        if let tf = state.textField { window.makeFirstResponder(tf) }

        // Fit to the freshly-loaded content once SwiftUI has laid it out. Animate
        // the step transition (non-fresh); keep the first-appear correction instant.
        DispatchQueue.main.async { [weak self] in self?.resizeToFit(animated: !fresh) }
    }

    // Match the window height to the SwiftUI content, anchoring the top edge so
    // the list grows/shrinks downward as the query filters it.
    // animated=true gives a slight eased height/width tween — used for the step
    // transitions (step 1 → skeleton → step 2). Typing-driven resizes pass false
    // so filtering stays instant/snappy.
    func resizeToFit(animated: Bool = false) {
        guard window.isVisible else { return }
        hosting.layoutSubtreeIfNeeded()
        let h = hosting.fittingSize.height
        let w = state.targetWidth
        guard h > 1,
              abs(h - window.frame.height) > 0.5 || abs(w - window.frame.width) > 0.5 else { return }
        let oldTop = window.frame.maxY
        var f = window.frame
        f.size.height = h
        f.size.width = w
        f.origin.y = oldTop - h          // anchor the top edge; grow/shrink downward
        if let vf = (window.screen ?? NSScreen.main)?.visibleFrame {
            f.origin.x = vf.midX - w / 2  // keep centered if the width changed
        }
        if animated {
            // Pin the content to its FINAL height at the current top edge before
            // tweening. With the .minYMargin autoresizing mask the content then
            // stays put (top-anchored) while the window reveals/covers from the
            // bottom — no vertical slide.
            let contentH = window.contentView?.bounds.height ?? window.frame.height
            hosting.frame = NSRect(x: 0, y: contentH - h, width: w, height: h)
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.09
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                ctx.allowsImplicitAnimation = true
                window.animator().setFrame(f, display: true)
            }
        } else {
            // Commit the frame + hosting bounds atomically with implicit animation
            // off, so the blur material can't animate/flicker through the resize.
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            window.setFrame(f, display: true)
            hosting.frame = window.contentView?.bounds ?? .zero
            CATransaction.commit()
        }
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
        case .hideNow:
            state.isVisible = false
            hideNow()
            if commit.pasteAfter { restoreFocusAndPaste() }
        case .linger:
            state.isVisible = false
            startLinger()
        case .loading:
            // Keep the window up (and key, so click-away still cancels) until the
            // two-step command's step 2 calls present() and swaps the content in.
            startLoading()
        }
    }

    // MARK: Hide / linger / loading

    func hideNow() {
        cancelLinger()
        window.orderOut(nil)
    }

    // Hand focus back to the app that was frontmost before choose appeared, then
    // synthesize ⌘V once it's active. The small delay lets the activation settle
    // so the keystroke lands in the target app rather than the just-hidden window.
    private func restoreFocusAndPaste() {
        guard let app = capturedApp else { return }
        app.activate(options: [.activateIgnoringOtherApps])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            Paste.sendCommandV()
        }
    }

    private func startLinger() {
        cancelLinger()
        let work = DispatchWorkItem { [weak self] in self?.fadeOut() }
        lingerItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    // Show the skeleton after a short grace period (so fast sub-commands swap
    // with no flash), and fall back to fading out if step 2 never arrives. We do
    // NOT resize here — the skeleton fills the window at its current (step 1)
    // height, so there's no arbitrary intermediary height; the single animated
    // resize happens only when step 2's real content lands.
    private func startLoading() {
        cancelLinger()
        let show = DispatchWorkItem { [weak self] in self?.state.isLoading = true }
        spinnerItem = show
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: show)

        let fallback = DispatchWorkItem { [weak self] in
            self?.state.isLoading = false
            self?.fadeOut()
        }
        lingerItem = fallback
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0, execute: fallback)
    }

    private func cancelLinger() {
        lingerItem?.cancel()
        lingerItem = nil
        spinnerItem?.cancel()
        spinnerItem = nil
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
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--copy-file"), i + 1 < args.count {
            CopyFileMode.run(path: args[i + 1])
        } else if args.contains("--check-accessibility") {
            // Silent trust check for scripted verification. AXIsProcessTrusted
            // reflects THIS binary's code identity, so run it from the signed copy
            // to confirm the daemon's identity holds the grant.
            print(AXIsProcessTrusted() ? "true" : "false")
        } else if args.contains("--request-accessibility") {
            // One-shot bootstrap: fire the system "add to Accessibility" prompt.
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            print(AXIsProcessTrustedWithOptions(opts) ? "true" : "false")
        } else if args.contains("--daemon") {
            DaemonMode.run()
        } else {
            ClientMode.run()
        }
    }
}

// `choose --copy-file <path>`: copy a file to the clipboard as both image and
// file reference (see Pasteboard.copyFile) and exit. Synchronous — no run loop.
enum CopyFileMode {
    static func run(path: String) {
        Pasteboard.copyFile(URL(fileURLWithPath: path))
        exit(0)
    }
}

// MARK: - Argument / Config Parsing

struct Invocation {
    var placeholder: String?
    var icon: String?
    var launcher = false
    var clipboard = false
    var emoji = false
    var screenshots = false
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
        EmojiStore.shared.warm()   // filter the dataset to OS-renderable glyphs off the main thread

        // Clipboard history watcher: poll the pasteboard while the daemon lives.
        if Settings.load().clipboard.enabled {
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                ClipboardStore.shared.poll()
            }
        }

        let cleanupAndExit: @convention(c) (Int32) -> Void = { _ in
            unlink(SocketConfig.path); _exit(0)
        }
        signal(SIGTERM, cleanupAndExit)
        signal(SIGINT, cleanupAndExit)

        DispatchQueue.global(qos: .userInitiated).async {
            startSocketServer(state: state, ui: ui)
        }

        NSLog("choose daemon started, listening on \(SocketConfig.path)")
        NSLog("choose daemon accessibility trusted=\(AXIsProcessTrusted())")
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
            if p.count > 3 && p[3] == "clipboard" { inv.clipboard = true }
            if p.count > 3 && p[3] == "emoji" { inv.emoji = true }
            if p.count > 3 && p[3] == "screenshots" { inv.screenshots = true }
            if p.count > 4, let m = Int(p[4]) { inv.maxEmpty = m }
            itemLines = Array(lines.dropFirst())
        }

        let semaphore = DispatchSemaphore(value: 0)
        var result = ""
        let metrics = Settings.load().metrics   // re-read per request so edits apply live

        DispatchQueue.main.async {
            state.reset()
            state.metrics = metrics
            if inv.clipboard {
                state.loadClipboard(placeholder: inv.placeholder)
            } else if inv.emoji {
                state.loadEmoji(placeholder: inv.placeholder)
            } else if inv.screenshots {
                state.loadScreenshots(placeholder: inv.placeholder)
            } else {
                state.load(lines: itemLines, placeholder: inv.placeholder, icon: inv.icon,
                           launcher: inv.launcher, maxEmpty: inv.maxEmpty)
            }
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
            case "--clipboard":         inv.clipboard = true
            case "--emoji":             inv.emoji = true
            case "--screenshots":       inv.screenshots = true
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

        let mode = inv.launcher ? "launcher"
            : (inv.clipboard ? "clipboard"
            : (inv.emoji ? "emoji"
            : (inv.screenshots ? "screenshots" : "")))
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
        if inv.clipboard {
            state.loadClipboard(placeholder: inv.placeholder)
        } else if inv.emoji {
            state.loadEmoji(placeholder: inv.placeholder)
        } else if inv.screenshots {
            state.loadScreenshots(placeholder: inv.placeholder)
        } else {
            state.load(lines: lines, placeholder: inv.placeholder, icon: inv.icon,
                       launcher: inv.launcher, maxEmpty: inv.maxEmpty)
        }

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
    @State private var selectedIndex = 0
    @State private var revealed = false   // compact mode: list shown after ↓ / typing

    var rowHeight: CGFloat { state.metrics.rowHeight }
    var maxVisibleItems: Int { state.metrics.maxVisibleItems }

    var queryIsEmpty: Bool {
        state.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // True when any item carries a group → render with section headers.
    var hasGroups: Bool { state.items.contains { $0.group != nil } }

    // Distinct groups in first-seen (input) order; this is the section order.
    var groupOrder: [String] {
        var seen = Set<String>(); var order: [String] = []
        for it in state.items {
            if let g = it.group, !seen.contains(g) { seen.insert(g); order.append(g) }
        }
        return order
    }

    // Re-bucket a priority-ordered list into section order, preserving each
    // item's incoming order within its section. (Swift's sort isn't stable, so
    // we bucket explicitly rather than sort by group index.)
    func grouped(_ items: [ChooseItem]) -> [ChooseItem] {
        guard hasGroups else { return items }
        var buckets: [String: [ChooseItem]] = [:]
        for it in items { buckets[it.group ?? "", default: []].append(it) }
        return groupOrder.flatMap { buckets[$0] ?? [] }
    }

    var filtered: [ChooseItem] {
        let base: [ChooseItem]
        if queryIsEmpty {
            base = Array(state.itemsSorted.prefix(state.maxEmpty))
        } else {
            let q = Array(state.query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
            let scored = state.items.compactMap { item -> (ChooseItem, Double)? in
                guard let s = state.matchScore(item, query: q) else { return nil }
                return (item, s)
            }
            base = scored.sorted { $0.1 > $1.1 }.map { $0.0 }
        }
        return grouped(base)
    }

    // In compact mode the launcher hides its list on an empty query until the
    // user types or presses ↓. This is a launcher-only affordance — utility /
    // second-step menus (ports, brew, force-quit…) always show their list.
    var showList: Bool {
        if !queryIsEmpty { return true }
        if state.isLauncher && state.metrics.hideEmptyList { return revealed }
        return true
    }

    var visible: [ChooseItem] { showList ? filtered : [] }

    var selectedItem: ChooseItem? {
        guard selectedIndex < visible.count else { return nil }
        return visible[selectedIndex]
    }

    // Render model: section headers interleaved with the selectable items.
    // `index` is the position in `visible` (headers are not selectable, so
    // keyboard nav over `visible` skips them for free).
    enum RenderRow: Identifiable {
        case header(String)
        case item(ChooseItem, Int)
        var id: String {
            switch self {
            case .header(let g): return "header:\(g)"
            case .item(let it, _): return "item:\(it.id)"
            }
        }
    }

    var renderRows: [RenderRow] {
        var rows: [RenderRow] = []
        var lastGroup: String?? = .none
        for (i, item) in visible.enumerated() {
            if hasGroups, item.group != (lastGroup ?? nil) {
                if let g = item.group { rows.append(.header(g)) }
                lastGroup = .some(item.group)
            }
            rows.append(.item(item, i))
        }
        return rows
    }

    var listHeight: CGFloat {
        let cap = min(visible.count, maxVisibleItems)
        guard hasGroups else { return CGFloat(cap) * rowHeight }
        // Fit `cap` items plus whatever headers precede them in the window.
        var items = 0, headers = 0
        for row in renderRows {
            if items >= cap { break }
            switch row {
            case .header: headers += 1
            case .item: items += 1
            }
        }
        return CGFloat(cap) * rowHeight + CGFloat(headers) * GroupHeaderRow.height
    }

    var body: some View {
        Group {
            if state.isLoading {
                SkeletonView(state: state)
            } else if state.displayMode == .clipboard {
                ClipboardView(state: state)
            } else if state.displayMode == .emoji {
                EmojiView(state: state)
            } else if state.displayMode == .screenshots {
                ScreenshotsView(state: state)
            } else {
                launcherBody
            }
        }
        // New identity per request resets the child views' @State (clipboard /
        // emoji / screenshots queries).
        .id(state.requestID)
        // query itself is cleared synchronously in reset() (no flash). These are
        // local @State, so reset them per request here.
        .onReceive(state.$requestID) { _ in
            selectedIndex = 0
            revealed = false
        }
    }

    var launcherBody: some View {
        VStack(spacing: 0) {
            // Search header
            HStack(spacing: 12) {
                Image(systemName: state.globalIcon ?? "magnifyingglass")
                    .font(.system(size: state.metrics.searchIconSize, weight: .medium))
                    .foregroundColor(Theme.subtext)
                CustomTextField(
                    text: $state.query,
                    selectedIndex: $selectedIndex,
                    itemCount: visible.count,
                    placeholder: state.placeholderText,
                    fontSize: state.metrics.searchFontSize,
                    state: state,
                    onSubmit: { action in select(action: action) },
                    onRevealDown: { revealed = true }
                )
            }
            .padding(.horizontal, 20)
            .frame(height: state.metrics.headerHeight)

            if !visible.isEmpty {
                Divider().background(Theme.surface1.opacity(0.3))

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(renderRows) { row in
                                switch row {
                                case .header(let title):
                                    GroupHeaderRow(title: title)
                                        .frame(height: GroupHeaderRow.height)
                                        .id(row.id)
                                case .item(let item, let i):
                                    ItemRow(item: item, isSelected: i == selectedIndex)
                                        .frame(height: rowHeight)
                                        .id(item.id)
                                        .onTapGesture { selectedIndex = i; select(action: "enter") }
                                }
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .frame(height: listHeight + 12)
                    .onChange(of: selectedIndex) {
                        if selectedIndex < visible.count { proxy.scrollTo(visible[selectedIndex].id) }
                    }
                }

                if let item = selectedItem {
                    Divider().background(Theme.surface1.opacity(0.3))
                    ActionBar(actions: item.actions)
                        .frame(height: 44)
                }
            }
        }
        .frame(width: state.metrics.width)
        .fixedSize(horizontal: false, vertical: true)
        .background(Theme.base.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onChange(of: state.query) { selectedIndex = 0; revealed = false }
        .onChange(of: visible.count) { state.onResize?() }
        .onChange(of: renderRows.count) { state.onResize?() }
        .onChange(of: state.requestID) { selectedIndex = 0; revealed = false; state.onResize?() }
    }

    func select(action: String) {
        if visible.isEmpty {
            if !state.query.isEmpty { state.commitText(state.query) } else { state.cancel() }
            return
        }
        guard selectedIndex < visible.count else { state.cancel(); return }
        state.commit(visible[selectedIndex], action: action)
    }
}

// MARK: - Loading (skeleton) View

// Shown between a two-step command's steps. The search header stays put — now
// carrying the command's name + icon with a cleared field, matching the step-2
// header that's about to arrive — while the results area shows pulsing skeleton
// rows. Reads as "results loading", not a window reload.
struct SkeletonView: View {
    @ObservedObject var state: DaemonState

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: state.loadingIcon)
                    .font(.system(size: state.metrics.searchIconSize, weight: .medium))
                    .foregroundColor(Theme.subtext)
                Text(state.loadingTitle)
                    .font(.system(size: state.metrics.searchFontSize, weight: .regular))
                    .foregroundColor(Theme.subtext0)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 20)
            .frame(height: state.metrics.headerHeight)

            Divider().background(Theme.surface1.opacity(0.3))

            // Fill the window at its CURRENT height (it isn't resized when loading
            // begins) with exactly enough skeleton rows — no arbitrary intermediary
            // height. The single animated resize happens when step 2's data lands.
            GeometryReader { geo in
                let n = max(1, Int(geo.size.height / state.metrics.rowHeight))
                VStack(spacing: 0) {
                    ForEach(0..<n, id: \.self) { i in
                        SkeletonRow(delay: Double(i) * 0.1)
                            .frame(height: state.metrics.rowHeight)
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(.vertical, 6)
        }
        .frame(width: state.targetWidth)
        .frame(maxHeight: .infinity)
        .background(Theme.base.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// A single placeholder row with a staggered, gentle pulse.
struct SkeletonRow: View {
    let delay: Double
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Theme.surface1)
                .frame(width: 24, height: 24)
            RoundedRectangle(cornerRadius: 5)
                .fill(Theme.surface1)
                .frame(width: 150, height: 11)
            Spacer()
        }
        .padding(.horizontal, 18)
        .opacity(pulse ? 0.9 : 0.3)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true).delay(delay)) {
                pulse = true
            }
        }
    }
}

// MARK: - Clipboard View

func relativeTime(_ ts: Double) -> String {
    let s = max(0, Date().timeIntervalSince1970 - ts)
    if s < 60 { return "just now" }
    if s < 3600 { return "\(Int(s / 60))m ago" }
    if s < 86400 { return "\(Int(s / 3600))h ago" }
    return "\(Int(s / 86400))d ago"
}

// Resolves a source app's icon from its bundle id (cached), falling back to an
// SF Symbol by clip kind.
final class AppIconResolver {
    static let shared = AppIconResolver()
    private let cache = NSCache<NSString, NSImage>()

    func icon(forBundleId bundleId: String?, kind: ClipKind) -> NSImage {
        if let b = bundleId {
            if let c = cache.object(forKey: b as NSString) { return c }
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: b) {
                let icon = NSWorkspace.shared.icon(forFile: url.path)
                cache.setObject(icon, forKey: b as NSString)
                return icon
            }
        }
        let name = kind == .image ? "photo" : "doc.on.clipboard"
        return NSImage(systemSymbolName: name, accessibilityDescription: nil) ?? NSImage()
    }
}

struct ClipboardView: View {
    @ObservedObject var state: DaemonState
    @State private var query = ""
    @State private var selectedIndex = 0

    var filtered: [ClipEntry] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return state.clipEntries }
        return state.clipEntries.filter {
            $0.preview.lowercased().contains(q) || ($0.appName?.lowercased().contains(q) ?? false)
        }
    }

    var selected: ClipEntry? {
        guard selectedIndex < filtered.count else { return nil }
        return filtered[selectedIndex]
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Theme.subtext)
                CustomTextField(
                    text: $query, selectedIndex: $selectedIndex,
                    itemCount: filtered.count, placeholder: state.placeholderText,
                    fontSize: 18, state: state, onSubmit: { _ in commit() }
                )
            }
            .padding(.horizontal, 20)
            .frame(height: 52)

            Divider().background(Theme.surface1.opacity(0.3))

            HStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(filtered.enumerated()), id: \.element.id) { i, entry in
                                ClipRow(entry: entry, isSelected: i == selectedIndex)
                                    .id(entry.id)
                                    .onTapGesture { selectedIndex = i; commit() }
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .onChange(of: selectedIndex) {
                        if selectedIndex < filtered.count { proxy.scrollTo(filtered[selectedIndex].id) }
                    }
                }
                .frame(width: ClipboardLayout.listWidth)

                Divider().background(Theme.surface1.opacity(0.3))

                ClipPreview(entry: selected)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxHeight: .infinity)
        }
        .frame(width: ClipboardLayout.width, height: ClipboardLayout.height)
        .background(Theme.base.opacity(0.55))
        .onChange(of: query) { selectedIndex = 0 }
        .onChange(of: state.requestID) { query = ""; selectedIndex = 0 }
    }

    func commit() {
        guard let entry = selected else { state.cancel(); return }
        state.commitClip(entry)
    }
}

struct ClipRow: View {
    let entry: ClipEntry
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: AppIconResolver.shared.icon(forBundleId: entry.bundleId, kind: entry.kind))
                .resizable().aspectRatio(contentMode: .fit)
                .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.kind == .image ? "Image — \(entry.preview)" : entry.preview)
                    .foregroundColor(Theme.text)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text([entry.appName, relativeTime(entry.ts)].compactMap { $0 }.joined(separator: " · "))
                    .foregroundColor(Theme.subtext0)
                    .font(.system(size: 11))
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
        }
        .padding(.horizontal, 12)
        .frame(height: ClipboardLayout.rowHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Theme.mauve.opacity(0.20) : Color.clear)
                .padding(.horizontal, 6)
        )
        .contentShape(Rectangle())
    }
}

struct ClipPreview: View {
    let entry: ClipEntry?

    var body: some View {
        if let entry = entry {
            VStack(alignment: .leading, spacing: 0) {
                if entry.kind == .image, let img = ClipboardStore.shared.image(for: entry) {
                    ScrollView {
                        Image(nsImage: img)
                            .resizable().aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .padding(16)
                    }
                } else {
                    ScrollView {
                        Text(ClipboardStore.shared.text(for: entry))
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(Theme.text)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                    }
                }
                Divider().background(Theme.surface1.opacity(0.3))
                HStack(spacing: 8) {
                    Text([entry.appName, entry.kind == .image ? entry.preview : nil]
                        .compactMap { $0 }.joined(separator: " · "))
                        .foregroundColor(Theme.subtext)
                    Spacer()
                    Text(relativeTime(entry.ts)).foregroundColor(Theme.subtext0)
                }
                .font(.system(size: 11))
                .padding(.horizontal, 16)
                .frame(height: 32)
            }
        } else {
            Text("No clipboard history yet")
                .foregroundColor(Theme.subtext0)
                .font(.system(size: 13))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Screenshots View

// Two-pane recent-screenshots picker: a filterable list on the left, a large
// preview of the highlighted shot on the right. Enter (or click) copies it to
// the clipboard as both image data and a file reference. Mirrors ClipboardView.
struct ScreenshotsView: View {
    @ObservedObject var state: DaemonState
    @State private var query = ""
    @State private var selectedIndex = 0

    var filtered: [ScreenshotEntry] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return state.screenshotEntries }
        return state.screenshotEntries.filter { $0.name.lowercased().contains(q) }
    }

    var selected: ScreenshotEntry? {
        guard selectedIndex < filtered.count else { return nil }
        return filtered[selectedIndex]
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Theme.subtext)
                CustomTextField(
                    text: $query, selectedIndex: $selectedIndex,
                    itemCount: filtered.count, placeholder: state.placeholderText,
                    fontSize: 18, state: state, onSubmit: { _ in commit() }
                )
            }
            .padding(.horizontal, 20)
            .frame(height: 52)

            Divider().background(Theme.surface1.opacity(0.3))

            if filtered.isEmpty {
                Text("No screenshots found")
                    .foregroundColor(Theme.subtext0)
                    .font(.system(size: 13))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(spacing: 0) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(filtered.enumerated()), id: \.element.id) { i, entry in
                                    ScreenshotRow(entry: entry, isSelected: i == selectedIndex)
                                        .id(entry.id)
                                        .onTapGesture { selectedIndex = i; commit() }
                                }
                            }
                            .padding(.vertical, 6)
                        }
                        .onChange(of: selectedIndex) {
                            if selectedIndex < filtered.count { proxy.scrollTo(filtered[selectedIndex].id) }
                        }
                    }
                    .frame(width: ScreenshotLayout.listWidth)

                    Divider().background(Theme.surface1.opacity(0.3))

                    ScreenshotPreview(entry: selected)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxHeight: .infinity)
            }
        }
        .frame(width: ScreenshotLayout.width, height: ScreenshotLayout.height)
        .background(Theme.base.opacity(0.55))
        .onChange(of: query) { selectedIndex = 0 }
        .onChange(of: state.requestID) { query = ""; selectedIndex = 0 }
    }

    func commit() {
        guard let entry = selected else { state.cancel(); return }
        state.commitScreenshot(entry)
    }
}

struct ScreenshotRow: View {
    let entry: ScreenshotEntry
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: ThumbResolver.shared.thumb(entry.path))
                .resizable().aspectRatio(contentMode: .fit)
                .frame(width: 48, height: 32)
                .background(Theme.surface0.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .foregroundColor(Theme.text)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1).truncationMode(.middle)
                Text(relativeTime(entry.ts))
                    .foregroundColor(Theme.subtext0)
                    .font(.system(size: 11))
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
        }
        .padding(.horizontal, 12)
        .frame(height: ScreenshotLayout.rowHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Theme.mauve.opacity(0.20) : Color.clear)
                .padding(.horizontal, 6)
        )
        .contentShape(Rectangle())
    }
}

struct ScreenshotPreview: View {
    let entry: ScreenshotEntry?

    var body: some View {
        if let entry = entry {
            VStack(alignment: .leading, spacing: 0) {
                ScrollView {
                    if let img = NSImage(contentsOfFile: entry.path) {
                        Image(nsImage: img)
                            .resizable().aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .padding(16)
                    } else {
                        Text("Can't preview \(entry.name)")
                            .foregroundColor(Theme.subtext0)
                            .padding(16)
                    }
                }
                Divider().background(Theme.surface1.opacity(0.3))
                HStack(spacing: 8) {
                    Text(entry.name).foregroundColor(Theme.subtext).lineLimit(1).truncationMode(.middle)
                    Spacer()
                    Text(relativeTime(entry.ts)).foregroundColor(Theme.subtext0)
                }
                .font(.system(size: 11))
                .padding(.horizontal, 16)
                .frame(height: 32)
            }
        } else {
            Text("No screenshots yet")
                .foregroundColor(Theme.subtext0)
                .font(.system(size: 13))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Emoji View

struct EmojiView: View {
    @ObservedObject var state: DaemonState
    @State private var query = ""
    @State private var selectedIndex = 0

    var filtered: [EmojiEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            // Empty query: most-used first (frecency), stable dataset order otherwise.
            return state.emojiEntries.enumerated().sorted { a, b in
                let fa = state.emojiFrecency(a.element.c)
                let fb = state.emojiFrecency(b.element.c)
                return fa != fb ? fa > fb : a.offset < b.offset
            }.map { $0.element }
        }
        let q = Array(trimmed.lowercased())
        let scored = state.emojiEntries.compactMap { e -> (EmojiEntry, Double)? in
            guard let s = state.emojiMatch(e, query: q) else { return nil }
            return (e, s)
        }
        return scored.sorted { $0.1 > $1.1 }.map { $0.0 }
    }

    var selected: EmojiEntry? {
        guard selectedIndex < filtered.count else { return nil }
        return filtered[selectedIndex]
    }

    var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 4), count: EmojiLayout.columns)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "face.smiling")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Theme.subtext)
                CustomTextField(
                    text: $query, selectedIndex: $selectedIndex,
                    itemCount: filtered.count, placeholder: state.placeholderText,
                    fontSize: 18, state: state,
                    onSubmit: { _ in commit() },
                    gridColumns: EmojiLayout.columns
                )
            }
            .padding(.horizontal, 20)
            .frame(height: 52)

            Divider().background(Theme.surface1.opacity(0.3))

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 4) {
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { i, e in
                            Text(e.c)
                                .font(.system(size: 26))
                                .frame(maxWidth: .infinity)
                                .frame(height: EmojiLayout.cellHeight)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(i == selectedIndex ? Theme.mauve.opacity(0.30) : Color.clear)
                                )
                                .id(e.c)
                                .onTapGesture { selectedIndex = i; commit() }
                        }
                    }
                    .padding(8)
                }
                .frame(height: EmojiLayout.gridHeight)
                .onChange(of: selectedIndex) {
                    if selectedIndex < filtered.count { proxy.scrollTo(filtered[selectedIndex].c) }
                }
            }

            Divider().background(Theme.surface1.opacity(0.3))

            HStack(spacing: 10) {
                if let e = selected {
                    Text(e.c).font(.system(size: 18))
                    Text(e.name)
                        .foregroundColor(Theme.subtext)
                        .font(.system(size: 12))
                        .lineLimit(1)
                } else {
                    Text("No match").foregroundColor(Theme.subtext0).font(.system(size: 12))
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(height: 36)
        }
        .frame(width: EmojiLayout.width)
        .fixedSize(horizontal: false, vertical: true)
        .background(Theme.base.opacity(0.55))
        .onChange(of: query) { selectedIndex = 0 }
        .onChange(of: state.requestID) { query = ""; selectedIndex = 0 }
    }

    func commit() {
        guard let e = selected else { state.cancel(); return }
        state.commitEmoji(e)
    }
}

// MARK: - GroupHeaderRow

// A non-selectable section header rendered between groups of items.
struct GroupHeaderRow: View {
    static let height: CGFloat = 28
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundColor(Theme.subtext0)
            .kerning(0.6)
            .padding(.horizontal, 22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: GroupHeaderRow.height, alignment: .bottom)
            .padding(.bottom, 4)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
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
        HStack(spacing: 0) {
            Spacer()
            ForEach(Array(actions.enumerated()), id: \.offset) { index, action in
                if index > 0 {
                    Rectangle()
                        .fill(Theme.surface1.opacity(0.6))
                        .frame(width: 1, height: 16)
                        .padding(.horizontal, 14)
                }
                HStack(spacing: 7) {
                    Text(action.label)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(Theme.subtext)
                    KeyCap(action.displayKey)
                }
            }
        }
        .padding(.horizontal, 18)
    }
}

struct KeyCap: View {
    let symbol: String
    init(_ symbol: String) { self.symbol = symbol }

    var body: some View {
        Text(symbol)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundColor(Theme.subtext)
            .frame(minWidth: 22, minHeight: 22)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Theme.surface1.opacity(0.5))
            )
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
    var onRevealDown: () -> Void = {}
    // >1 turns on 2D grid navigation (emoji): ↑↓ move by a row, ←→ by one cell.
    var gridColumns: Int = 1

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
        context.coordinator.parent = self
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
            let cols = max(1, parent.gridColumns)
            switch sel {
            case #selector(NSResponder.moveDown(_:)):
                if itemCount == 0 {
                    parent.onRevealDown()        // compact mode: ↓ reveals the list
                } else if parent.selectedIndex + cols < itemCount {
                    parent.selectedIndex += cols
                }
                return true
            case #selector(NSResponder.moveUp(_:)):
                if parent.selectedIndex - cols >= 0 { parent.selectedIndex -= cols }
                return true
            case #selector(NSResponder.moveRight(_:)) where cols > 1:
                if parent.selectedIndex < itemCount - 1 { parent.selectedIndex += 1 }
                return true
            case #selector(NSResponder.moveLeft(_:)) where cols > 1:
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
