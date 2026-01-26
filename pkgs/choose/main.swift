import SwiftUI

// Read stdin before app starts (blocking)
let stdinItems: [String] = {
    var lines: [String] = []
    while let line = readLine() {
        lines.append(line)
    }
    return lines
}()

@main
struct ChooseApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(items: stdinItems)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}

struct ContentView: View {
    @State private var query = ""
    @State private var selectedIndex = 0
    let items: [String]

    // Catppuccin Mocha
    let base = Color(hex: "1e1e2e")
    let surface0 = Color(hex: "313244")
    let text = Color(hex: "cdd6f4")
    let subtext = Color(hex: "a6adc8")
    let mauve = Color(hex: "cba6f7")

    var filtered: [String] {
        if query.isEmpty { return items }
        return items.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            TextField("Search...", text: $query)
                .textFieldStyle(.plain)
                .padding(12)
                .background(surface0)
                .foregroundColor(text)
                .font(.system(size: 18, weight: .medium, design: .monospaced))
                .onSubmit { selectItem() }
                .onChange(of: query) { selectedIndex = 0 }

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(filtered.enumerated()), id: \.offset) { index, item in
                            HStack {
                                Text(item)
                                    .foregroundColor(index == selectedIndex ? base : text)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(index == selectedIndex ? mauve : Color.clear)
                            .id(index)
                            .onTapGesture {
                                selectedIndex = index
                                selectItem()
                            }
                        }
                    }
                }
                .onChange(of: selectedIndex) { proxy.scrollTo(selectedIndex) }
            }
        }
        .frame(width: 400, height: 300)
        .background(base)
        .font(.system(size: 16, design: .monospaced))
        .onKeyPress(.downArrow) { move(1); return .handled }
        .onKeyPress(.upArrow) { move(-1); return .handled }
        .onKeyPress(.escape) { NSApp.terminate(nil); return .handled }
    }

    func move(_ delta: Int) {
        let newIndex = selectedIndex + delta
        if newIndex >= 0 && newIndex < filtered.count {
            selectedIndex = newIndex
        }
    }

    func selectItem() {
        guard !filtered.isEmpty else { return }
        print(filtered[selectedIndex])
        NSApp.terminate(nil)
    }
}

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}
