import SwiftUI

@main struct TeamsBackgroundsApp: App {
    init() {
        PreferenceKey.registerDefaults()
    }

    var body: some Scene {
        WindowGroup("Teams Backgrounds") {
            ContentView()
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Teams Backgrounds") {
                    AboutPanel.show()
                }
            }
            HelpCommands()
        }

        Window("Finding Your Developer ID", id: SigningHelpView.windowID) {
            SigningHelpView()
        }
        .defaultSize(width: 680, height: 720)

        Settings {
            SettingsView()
        }
    }
}

/// Replaces the default "Help isn't available" item with the Developer ID article.
private struct HelpCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .help) {
            Button("Finding Your Developer ID") {
                openWindow(id: SigningHelpView.windowID)
            }
        }
    }
}

/// Shows the standard macOS About panel with author and license credits.
enum AboutPanel {
    static let licenseURL = URL(string: "https://opensource.org/license/mit")

    static func show() {
        NSApplication.shared.orderFrontStandardAboutPanel(options: [
            .applicationName: "Teams Backgrounds",
            .credits: credits(),
            NSApplication.AboutPanelOptionKey(rawValue: "Copyright"): "Copyright © 2026 Russell Collis"
        ])
        NSApplication.shared.activate()
    }

    private static func credits() -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center

        let base: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph
        ]

        let text = NSMutableAttributedString(
            string: "Created by Russell Collis\n\nPackages images as custom Microsoft Teams backgrounds for deployment as a Folder, DMG or PKG.\n\nReleased under the ",
            attributes: base
        )
        var link = base
        if let licenseURL {
            link[.link] = licenseURL
        }
        text.append(NSAttributedString(string: "MIT License", attributes: link))
        text.append(NSAttributedString(string: ".", attributes: base))
        return text
    }
}
