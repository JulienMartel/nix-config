import SwiftUI
import AppKit

// MARK: - Data Types

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

    static func parse(_ line: String, globalIcon: String?) -> ChooseItem {
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
                    if kv.count == 2 {
                        actions.append(ItemAction(key: kv[0], label: kv[1]))
                    }
                }
            }
        }

        if actions.isEmpty {
            actions.append(ItemAction(key: "enter", label: "Select"))
        }

        return ChooseItem(raw: line, title: title, subtitle: subtitle, icon: icon, actions: actions)
    }

    func action(for key: String) -> ItemAction? {
        return actions.first { $0.key == key }
    }
}

// MARK: - Frecency

class Frecency {
    struct Entry: Codable {
        var count: Int
        var lastUsed: Double
    }

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
              let decoded = try? JSONDecoder().decode([String: Entry].self, from: raw)
        else { return }
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

// MARK: - DaemonState (replaces AppState)

class DaemonState: ObservableObject {
    @Published var items: [ChooseItem] = []
    @Published var placeholderText: String = "Search..."
    @Published var globalIcon: String? = nil
    @Published var isVisible: Bool = false
    @Published var requestID = UUID()

    let frecency = Frecency()
    var onResult: ((String) -> Void)?
    weak var textField: NSTextField?

    func reset() {
        items = []
        placeholderText = "Search..."
        globalIcon = nil
        requestID = UUID()
    }

    func loadItems(lines: [String], placeholder: String?, icon: String?) {
        globalIcon = icon
        placeholderText = placeholder ?? (lines.isEmpty ? "Input..." : "Search...")
        items = lines.map { ChooseItem.parse($0, globalIcon: globalIcon) }
    }
}

// MARK: - Socket Path

enum SocketConfig {
    static let dir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".local/share/choose").path
    static let path = dir + "/choose.sock"
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

// MARK: - Window Setup (shared between daemon and direct mode)

class ChooseWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

func makeWindow() -> ChooseWindow {
    let window = ChooseWindow(
        contentRect: NSRect(x: 0, y: 0, width: 700, height: 400),
        styleMask: [.borderless, .fullSizeContentView],
        backing: .buffered,
        defer: false
    )
    window.titlebarAppearsTransparent = true
    window.titleVisibility = .hidden
    window.isMovableByWindowBackground = true
    window.backgroundColor = NSColor(Color(hex: "1e1e2e"))
    window.level = .floating
    window.hasShadow = true
    window.isOpaque = false
    window.center()
    return window
}

// MARK: - Daemon Mode

enum DaemonMode {
    static func run() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        let state = DaemonState()

        let contentView = ContentView(state: state)
        let hostingView = NSHostingView(rootView: contentView)

        let window = makeWindow()
        window.contentView = hostingView
        window.orderOut(nil)

        // Resign key = dismiss
        NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: window,
            queue: .main
        ) { _ in
            if state.isVisible {
                state.onResult?("")
            }
        }

        // Clean up socket on termination signals
        let cleanupAndExit: @convention(c) (Int32) -> Void = { _ in
            unlink(SocketConfig.path)
            _exit(0)
        }
        signal(SIGTERM, cleanupAndExit)
        signal(SIGINT, cleanupAndExit)

        // Start socket server on background queue
        DispatchQueue.global(qos: .userInitiated).async {
            startSocketServer(state: state, window: window)
        }

        NSLog("choose daemon started, listening on \(SocketConfig.path)")
        app.run()
    }

    static func startSocketServer(state: DaemonState, window: NSWindow) {
        // Clean up stale socket
        unlink(SocketConfig.path)

        // Ensure directory exists
        try? FileManager.default.createDirectory(
            atPath: SocketConfig.dir,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            NSLog("choose daemon: failed to create socket")
            return
        }

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
        }) == 0 else {
            NSLog("choose daemon: failed to bind socket")
            close(fd)
            return
        }

        guard listen(fd, 5) == 0 else {
            NSLog("choose daemon: failed to listen")
            close(fd)
            return
        }

        // Accept loop
        while true {
            var clientAddr = sockaddr_un()
            var clientLen = socklen_t(MemoryLayout<sockaddr_un>.size)
            let clientFD = withUnsafeMutablePointer(to: &clientAddr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    accept(fd, $0, &clientLen)
                }
            }
            guard clientFD >= 0 else { continue }

            handleClient(clientFD: clientFD, state: state, window: window)
        }
    }

    static func handleClient(clientFD: Int32, state: DaemonState, window: NSWindow) {
        // Read all data from client
        var data = Data()
        var buf = [UInt8](repeating: 0, count: 65536)
        while true {
            let n = read(clientFD, &buf, buf.count)
            if n <= 0 { break }
            data.append(contentsOf: buf[0..<n])
        }

        guard let payload = String(data: data, encoding: .utf8), !payload.isEmpty else {
            close(clientFD)
            return
        }

        var lines = payload.components(separatedBy: "\n")
        // Remove trailing empty line from final \n
        if lines.last == "" { lines.removeLast() }

        // Parse CONFIG line
        var placeholder: String? = nil
        var icon: String? = nil
        var itemLines: [String] = []

        if let first = lines.first, first.hasPrefix("CONFIG\t") {
            let configParts = first.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            if configParts.count > 1 && !configParts[1].isEmpty { placeholder = configParts[1] }
            if configParts.count > 2 && !configParts[2].isEmpty { icon = configParts[2] }
            itemLines = Array(lines.dropFirst())
        } else {
            itemLines = lines
        }

        let semaphore = DispatchSemaphore(value: 0)
        var result = ""

        DispatchQueue.main.async {
            state.reset()
            state.loadItems(lines: itemLines, placeholder: placeholder, icon: icon)
            state.onResult = { r in
                result = r
                state.isVisible = false
                window.orderOut(nil)
                semaphore.signal()
            }
            state.isVisible = true

            // Let SwiftUI lay out with new items, then size and show
            DispatchQueue.main.async {
                if let hostingView = window.contentView as? NSHostingView<ContentView> {
                    let size = hostingView.fittingSize
                    window.setContentSize(size)
                }
                window.center()
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)

                if let tf = state.textField {
                    window.makeFirstResponder(tf)
                }
            }
        }

        semaphore.wait()

        // Send result back to client
        if !result.isEmpty {
            let resultData = (result + "\n").data(using: .utf8)!
            resultData.withUnsafeBytes { ptr in
                _ = write(clientFD, ptr.baseAddress!, resultData.count)
            }
        }
        close(clientFD)
    }
}

// MARK: - Client Mode

enum ClientMode {
    static func run() {
        // Read stdin
        var stdinLines: [String] = []
        if isatty(FileHandle.standardInput.fileDescriptor) == 0 {
            while let line = readLine() { stdinLines.append(line) }
        }

        // Parse config from args
        var placeholder: String? = nil
        var icon: String? = nil
        var args = Array(CommandLine.arguments.dropFirst())
        while !args.isEmpty {
            let arg = args.removeFirst()
            switch arg {
            case "-p", "--placeholder":
                if !args.isEmpty { placeholder = args.removeFirst() }
            case "-i", "--icon":
                if !args.isEmpty { icon = args.removeFirst() }
            default:
                break
            }
        }

        // Try connecting to daemon
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            runDirect(lines: stdinLines, placeholder: placeholder, icon: icon)
            return
        }

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

        if !connected {
            close(fd)
            runDirect(lines: stdinLines, placeholder: placeholder, icon: icon)
            return
        }

        // Build payload: CONFIG line + item lines
        var payload = "CONFIG\t\(placeholder ?? "")\t\(icon ?? "")\n"
        for line in stdinLines {
            payload += line + "\n"
        }

        // Send payload then shutdown write end
        if let data = payload.data(using: .utf8) {
            data.withUnsafeBytes { ptr in
                _ = write(fd, ptr.baseAddress!, data.count)
            }
        }
        shutdown(fd, SHUT_WR)

        // Read result
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
            print(result)
            exit(0)
        } else {
            exit(1)
        }
    }

    // Direct mode: run NSApplication inline (fallback when daemon is not running)
    static func runDirect(lines: [String], placeholder: String?, icon: String?) {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        let state = DaemonState()
        state.loadItems(lines: lines, placeholder: placeholder, icon: icon)

        let contentView = ContentView(state: state)
        let hostingView = NSHostingView(rootView: contentView)

        let window = makeWindow()
        window.contentView = hostingView

        state.onResult = { result in
            if !result.isEmpty {
                print(result)
                NSApp.terminate(nil)
            } else {
                exit(1)
            }
        }

        // Resign key = dismiss
        NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: window,
            queue: .main
        ) { _ in
            state.onResult?("")
        }

        state.isVisible = true

        // Let SwiftUI lay out, then size and show
        DispatchQueue.main.async {
            let size = hostingView.fittingSize
            window.setContentSize(size)
            window.center()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)

            if let tf = state.textField {
                window.makeFirstResponder(tf)
            }
        }

        app.run()
    }
}

// MARK: - ContentView

struct ContentView: View {
    @ObservedObject var state: DaemonState
    @State private var query = ""
    @State private var selectedIndex = 0

    let base = Color(hex: "1e1e2e")
    let surface0 = Color(hex: "313244")
    let surface1 = Color(hex: "45475a")
    let surface2 = Color(hex: "585b70")
    let text = Color(hex: "cdd6f4")
    let subtext = Color(hex: "a6adc8")
    let subtext0 = Color(hex: "6c7086")
    let mauve = Color(hex: "cba6f7")
    let blue = Color(hex: "89b4fa")
    let green = Color(hex: "a6e3a1")
    let peach = Color(hex: "fab387")

    let itemHeight: CGFloat = 36
    let maxVisibleItems = 12
    let actionBarHeight: CGFloat = 40

    var filtered: [ChooseItem] {
        let matched: [ChooseItem]
        if query.isEmpty {
            matched = state.items
        } else {
            let searchTerms = query.lowercased().split(separator: " ").map(String.init)
            matched = state.items.filter { item in
                let searchable = (item.title + " " + (item.subtitle ?? "")).lowercased()
                return searchTerms.allSatisfy { searchable.contains($0) }
            }
        }
        return matched.sorted { a, b in
            state.frecency.score(for: a.title) > state.frecency.score(for: b.title)
        }
    }

    var selectedItem: ChooseItem? {
        guard selectedIndex < filtered.count else { return nil }
        return filtered[selectedIndex]
    }

    var listHeight: CGFloat {
        let count = min(filtered.count, maxVisibleItems)
        return CGFloat(count) * itemHeight
    }

    var showActionBar: Bool {
        guard let item = selectedItem else { return false }
        return item.actions.count > 0
    }

    var body: some View {
        VStack(spacing: 0) {
            CustomTextField(
                text: $query,
                selectedIndex: $selectedIndex,
                itemCount: filtered.count,
                placeholder: state.placeholderText,
                state: state,
                onSubmit: { action in
                    select(action: action)
                }
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(surface0)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { i, item in
                            ItemRow(
                                item: item,
                                isSelected: i == selectedIndex,
                                base: base,
                                text: text,
                                subtext: subtext,
                                mauve: mauve
                            )
                            .frame(height: itemHeight)
                            .id(item.id)
                            .onTapGesture { selectedIndex = i; select(action: "enter") }
                        }
                    }
                }
                .frame(height: listHeight)
                .onChange(of: selectedIndex) {
                    if selectedIndex < filtered.count {
                        proxy.scrollTo(filtered[selectedIndex].id)
                    }
                }
            }

            if showActionBar, let item = selectedItem {
                Divider()
                    .background(surface1)

                ActionBar(
                    actions: item.actions,
                    surface0: surface0,
                    surface1: surface1,
                    surface2: surface2,
                    text: text,
                    subtext: subtext0,
                    blue: blue
                )
                .frame(height: actionBarHeight)
                .background(surface0.opacity(0.8))
            }
        }
        .frame(width: 700)
        .fixedSize(horizontal: false, vertical: true)
        .background(base)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onChange(of: query) { selectedIndex = 0 }
        .onChange(of: state.requestID) {
            query = ""
            selectedIndex = 0
        }
    }

    func select(action: String) {
        if filtered.isEmpty {
            if !query.isEmpty {
                state.onResult?("enter\t\(query)")
                return
            }
            state.onResult?("")
            return
        }
        guard selectedIndex < filtered.count else {
            state.onResult?("")
            return
        }
        let item = filtered[selectedIndex]
        state.frecency.record(item.title)

        if item.action(for: action) != nil {
            state.onResult?("\(action)\t\(item.raw)")
        } else {
            state.onResult?("enter\t\(item.raw)")
        }
    }
}

// MARK: - ItemRow

struct ItemRow: View {
    let item: ChooseItem
    let isSelected: Bool
    let base: Color
    let text: Color
    let subtext: Color
    let mauve: Color

    private var appIconPath: String? {
        guard let icon = item.icon, icon.hasPrefix("app:") else { return nil }
        return String(icon.dropFirst(4))
    }

    var body: some View {
        HStack(spacing: 10) {
            if let path = appIconPath {
                Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 22, height: 22)
            } else if let iconName = item.icon {
                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? base : subtext)
                    .frame(width: 22)
            }

            Text(item.title)
                .foregroundColor(isSelected ? base : text)
                .font(.system(size: 15, weight: .medium, design: .rounded))

            Spacer()

            if let subtitle = item.subtitle {
                Text(subtitle)
                    .foregroundColor(isSelected ? base.opacity(0.7) : subtext)
                    .font(.system(size: 13, design: .rounded))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(isSelected ? mauve : Color.clear)
        .contentShape(Rectangle())
    }
}

// MARK: - ActionBar

struct ActionBar: View {
    let actions: [ItemAction]
    let surface0: Color
    let surface1: Color
    let surface2: Color
    let text: Color
    let subtext: Color
    let blue: Color

    var body: some View {
        HStack(spacing: 16) {
            ForEach(Array(actions.enumerated()), id: \.offset) { index, action in
                HStack(spacing: 6) {
                    Text(action.displayKey)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(index == 0 ? surface0 : text)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(index == 0 ? blue : surface2)
                        .cornerRadius(4)

                    Text(action.label)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(index == 0 ? text : subtext)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 14)
    }
}

// MARK: - CustomTextField

struct CustomTextField: NSViewRepresentable {
    @Binding var text: String
    @Binding var selectedIndex: Int
    let itemCount: Int
    let placeholder: String
    let state: DaemonState
    let onSubmit: (String) -> Void

    func makeNSView(context: Context) -> NSTextField {
        let tf = NSTextField()
        tf.delegate = context.coordinator
        tf.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        tf.textColor = NSColor(Color(hex: "cdd6f4"))
        tf.backgroundColor = .clear
        tf.focusRingType = .none
        tf.isBordered = false
        tf.drawsBackground = false
        tf.placeholderString = placeholder
        tf.cell?.sendsActionOnEndEditing = false

        // Store weak ref for re-focusing
        DispatchQueue.main.async {
            state.textField = tf
            tf.window?.makeFirstResponder(tf)
        }
        return tf
    }

    func updateNSView(_ tf: NSTextField, context: Context) {
        if tf.stringValue != text { tf.stringValue = text }
        tf.placeholderString = placeholder
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
                if flags.contains(.command) {
                    parent.onSubmit("cmd")
                } else if flags.contains(.option) {
                    parent.onSubmit("opt")
                } else if flags.contains(.control) {
                    parent.onSubmit("ctrl")
                } else {
                    parent.onSubmit("enter")
                }
                return true
            case #selector(NSResponder.cancelOperation(_:)):
                parent.state.onResult?("")
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
        self.init(red: Double((rgb >> 16) & 0xFF) / 255, green: Double((rgb >> 8) & 0xFF) / 255, blue: Double(rgb & 0xFF) / 255)
    }
}
