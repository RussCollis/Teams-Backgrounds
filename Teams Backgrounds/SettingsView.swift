import SwiftUI

/// Settings window: remember last-used PKG values, or set defaults for new sessions.
struct SettingsView: View {
    @AppStorage(PreferenceKey.rememberLastSession) private var rememberLastSession = true
    @AppStorage(PreferenceKey.defaultPackageIdentifier) private var defaultIdentifier = ""
    @AppStorage(PreferenceKey.defaultSigningIdentity) private var defaultSigningIdentity = ""

    @State private var cleared = false

    var body: some View {
        Form {
            Section {
                Toggle("Remember identifier and signing identity from last session", isOn: $rememberLastSession)
                Button(cleared ? "Remembered Values Cleared" : "Clear Remembered Values") {
                    PreferenceKey.clearLastSession()
                    cleared = true
                }
                .disabled(cleared)
            } footer: {
                Text("When on, the PKG identifier and signing identity you last used are filled in each time the app opens. When off, or when nothing has been saved yet, the defaults below are used.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Defaults for New Sessions") {
                TextField("Identifier", text: $defaultIdentifier, prompt: Text(PreferenceKey.fallbackPackageIdentifier))
                SigningIdentityField(identity: $defaultSigningIdentity)
            }
        }
        .formStyle(.grouped)
        .frame(width: 560)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Text field for a "Developer ID Installer" identity, with a menu of the identities
/// found in the keychain and a link to the help article.
struct SigningIdentityField: View {
    @Binding var identity: String

    @State private var detected: [String] = []
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        LabeledContent("Signing identity") {
            HStack {
                TextField("Signing identity", text: $identity, prompt: Text("Optional: Developer ID Installer: …"))
                    .labelsHidden()

                Menu("Choose Identity", systemImage: "key") {
                    if detected.isEmpty {
                        Text("No Developer ID Installer identities found")
                    }
                    ForEach(detected, id: \.self) { name in
                        Button(name) { identity = name }
                    }
                    Divider()
                    Button("Don't Sign") { identity = "" }
                }
                .labelStyle(.iconOnly)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Choose a Developer ID Installer identity from your keychain")

                HelpLink {
                    openWindow(id: SigningHelpView.windowID)
                }
                .help("How to find your Developer ID")
            }
        }
        .task {
            detected = await SigningIdentities.installerIdentities()
        }
    }
}
