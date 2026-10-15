import AppKit
import ServiceManagement

struct Group {
    let name: String
    let normal: Double  // a esta temp o menos: texto translúcido
    let hot: Double     // a esta temp o más: rojo
}

// Umbrales aproximados para M1
let groups = [
    Group(name: "Chip (CPU/GPU)", normal: 55, hot: 95),
    Group(name: "SoC", normal: 55, hot: 90),
    Group(name: "SSD", normal: 45, hot: 70),
    Group(name: "Batería", normal: 35, hot: 45),
]

// 0 = normal, 1 = caliente
func heat(_ temp: Double, _ group: Group) -> Double {
    min(max((temp - group.normal) / (group.hot - group.normal), 0), 1)
}

// Translúcido → opaco en la primera mitad, opaco → rojo en la segunda
func color(for level: Double) -> NSColor {
    if level < 0.5 { return NSColor.labelColor.withAlphaComponent(0.45 + 0.55 * level / 0.5) }
    return NSColor.labelColor.blended(withFraction: (level - 0.5) / 0.5, of: .systemRed) ?? .systemRed
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private var groupItems: [NSMenuItem] = []
    private var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        try? SMAppService.mainApp.register()

        for (i, group) in groups.enumerated() {
            let item = NSMenuItem(title: group.name, action: nil, keyEquivalent: "")
            item.identifier = NSUserInterfaceItemIdentifier("group-\(i)")
            groupItems.append(item)
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Salir", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.identifier = NSUserInterfaceItemIdentifier("quit-button")
        menu.addItem(quit)
        statusItem.menu = menu

        update()
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in self?.update() }
    }

    private func update() {
        var temps = [Double](repeating: -1, count: 4)
        read_groups(&temps)

        var worst: (temp: Double, level: Double, index: Int)?
        for (i, group) in groups.enumerated() {
            let temp = temps[i]
            guard temp > 0 else {
                groupItems[i].title = "\(group.name)   --"
                continue
            }
            let level = heat(temp, group)
            if worst == nil || level > worst!.level {
                worst = (temp, level, i)
            }
            groupItems[i].title = "\(group.name)   \(Int(temp.rounded()))°C"
        }

        for (i, item) in groupItems.enumerated() { item.state = (i == worst?.index) ? .on : .off }

        let text = worst.map { "\(Int($0.temp.rounded()))°C" } ?? "--"
        let tint = color(for: worst?.level ?? 0)
        statusItem.button?.attributedTitle = NSAttributedString(string: text, attributes: [
            .foregroundColor: tint,
            .font: NSFont.menuBarFont(ofSize: 0),
        ])
    }
}

@main
enum TempBarApp {
    static let delegate = AppDelegate()
    static func main() {
        let app = NSApplication.shared
        app.delegate = delegate
        app.run()
    }
}
