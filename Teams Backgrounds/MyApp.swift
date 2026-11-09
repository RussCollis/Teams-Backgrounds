import SwiftUI

@main struct TeamsBackgroundsApp: App {
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
