import SwiftUI
import AppKit

// Action definition
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

// Represents a chooseable item with optional rich content and actions
struct ChooseItem: Identifiable {
    let id = UUID()
    let raw: String      // Original line (returned on selection)
    let title: String
    let subtitle: String?
    let icon: String?    // SF Symbol name
    let actions: [ItemAction]

    // Parse a line: "title\tsubtitle\ticon\tactions" or simpler formats
    // Actions format: "DefaultLabel|cmd:CmdLabel|opt:OptLabel|ctrl:CtrlLabel"
    static func parse(_ line: String, globalIcon: String?) -> ChooseItem {
        let parts = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)

        let title = parts.count > 0 ? parts[0] : line
        let subtitle = parts.count > 1 && !parts[1].isEmpty ? parts[1] : nil
        let icon = (parts.count > 2 && !parts[2].isEmpty ? parts[2] : nil) ?? globalIcon

        // Parse actions (4th field)
        var actions: [ItemAction] = []
        if parts.count > 3 && !parts[3].isEmpty {
            let actionParts = parts[3].split(separator: "|").map(String.init)
            for (index, part) in actionParts.enumerated() {
                if index == 0 {
                    // First part is default (enter) action
                    actions.append(ItemAction(key: "enter", label: part))
                } else if part.contains(":") {
                    let kv = part.split(separator: ":", maxSplits: 1).map(String.init)
                    if kv.count == 2 {
                        actions.append(ItemAction(key: kv[0], label: kv[1]))
                    }
                }
            }
        }

        // Default action if none specified
        if actions.isEmpty {
            actions.append(ItemAction(key: "enter", label: "Select"))
        }

        return ChooseItem(raw: line, title: title, subtitle: subtitle, icon: icon, actions: actions)
    }

    func action(for key: String) -> ItemAction? {
        return actions.first { $0.key == key }
    }
}

// Parse command-line arguments
struct Config {
    var placeholder: String?
    var icon: String?  // Global SF Symbol for all items

    static func parse() -> Config {
        var config = Config()
        var args = CommandLine.arguments.dropFirst()

        while let arg = args.first {
            args = args.dropFirst()
            switch arg {
            case "-p", "--placeholder":
                if let value = args.first {
                    config.placeholder = value
                    args = args.dropFirst()
                }
            case "-i", "--icon":
                if let value = args.first {
                    config.icon = value
                    args = args.dropFirst()
                }
            default:
                break
            }
        }
        return config
    }
}

// Global state computed at launch
enum AppState {
    static let config = Config.parse()

    static let stdinLines: [String] = {
        if isatty(FileHandle.standardInput.fileDescriptor) == 0 {
            var lines: [String] = []
            while let line = readLine() { lines.append(line) }
            return lines
        }
        return []
    }()

    static let stdinItems: [ChooseItem] = stdinLines.map { ChooseItem.parse($0, globalIcon: config.icon) }
    static let isInputMode = stdinItems.isEmpty
    static let placeholderText = config.placeholder ?? (isInputMode ? "Input..." : "Search...")
}

@main
struct ChooseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .background(WindowAccessor())
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.styleMask.insert(.fullSizeContentView)
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden
                window.standardWindowButton(.closeButton)?.isHidden = true
                window.standardWindowButton(.miniaturizeButton)?.isHidden = true
                window.standardWindowButton(.zoomButton)?.isHidden = true
                window.isMovableByWindowBackground = true
                window.backgroundColor = NSColor(Color(hex: "1e1e2e"))
                window.level = .floating
                window.center()

                NSApp.activate(ignoringOtherApps: true)
                window.makeKeyAndOrderFront(nil)

                NotificationCenter.default.addObserver(
                    forName: NSWindow.didResignKeyNotification,
                    object: window,
                    queue: .main
                ) { _ in
                    exit(1)
                }
            }
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct ContentView: View {
    @State private var query = ""
    @State private var selectedIndex = 0

    let items = AppState.stdinItems
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
        if query.isEmpty { return items }
        return items.filter { item in
            item.title.localizedCaseInsensitiveContains(query) ||
            (item.subtitle?.localizedCaseInsensitiveContains(query) ?? false)
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
            // Search field
            CustomTextField(
                text: $query,
                selectedIndex: $selectedIndex,
                itemCount: filtered.count,
                placeholder: AppState.placeholderText,
                onSubmit: { action in
                    select(action: action)
                }
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(surface0)

            // Item list
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
                            .id(i)
                            .onTapGesture { selectedIndex = i; select(action: "enter") }
                        }
                    }
                }
                .frame(height: listHeight)
                .onChange(of: selectedIndex) { proxy.scrollTo(selectedIndex) }
            }

            // Action bar (only if selected item has actions)
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
        .padding(.top, -28)
        .onChange(of: query) { selectedIndex = 0 }
    }

    func select(action: String) {
        if filtered.isEmpty {
            if !query.isEmpty {
                print("enter\t\(query)")
                exit(0)
            }
            exit(1)
        }
        guard selectedIndex < filtered.count else { exit(1) }
        let item = filtered[selectedIndex]

        // Check if the action exists for this item
        if item.action(for: action) != nil {
            print("\(action)\t\(item.raw)")
            exit(0)
        } else {
            // Fall back to enter action
            print("enter\t\(item.raw)")
            exit(0)
        }
    }
}

struct ItemRow: View {
    let item: ChooseItem
    let isSelected: Bool
    let base: Color
    let text: Color
    let subtext: Color
    let mauve: Color

    var body: some View {
        HStack(spacing: 10) {
            // Icon
            if let iconName = item.icon {
                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? base : subtext)
                    .frame(width: 22)
            }

            // Title
            Text(item.title)
                .foregroundColor(isSelected ? base : text)
                .font(.system(size: 15, weight: .medium, design: .rounded))

            Spacer()

            // Subtitle
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
                    // Key badge
                    Text(action.displayKey)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(index == 0 ? surface0 : text)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(index == 0 ? blue : surface2)
                        .cornerRadius(4)

                    // Label
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

struct CustomTextField: NSViewRepresentable {
    @Binding var text: String
    @Binding var selectedIndex: Int
    let itemCount: Int
    let placeholder: String
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

        DispatchQueue.main.async {
            tf.window?.makeFirstResponder(tf)
        }
        return tf
    }

    func updateNSView(_ tf: NSTextField, context: Context) {
        if tf.stringValue != text { tf.stringValue = text }
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
                // Check for modifier keys
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
                exit(1)
            default:
                return false
            }
        }
    }
}

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        self.init(red: Double((rgb >> 16) & 0xFF) / 255, green: Double((rgb >> 8) & 0xFF) / 255, blue: Double(rgb & 0xFF) / 255)
    }
}
