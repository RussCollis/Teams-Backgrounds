import SwiftUI

/// Help article: how to find (or create) the Developer ID used to sign the PKG.
struct SigningHelpView: View {
    static let windowID = "signing-help"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Finding Your Developer ID")
                    .font(.largeTitle.bold())

                Text("Signing the PKG with a **Developer ID Installer** certificate lets Gatekeeper and your MDM (Intune, Jamf, …) verify who built it and that it hasn't been changed. Signing is optional, but unsigned packages are blocked when opened from a download.")

                HelpSection("1. List your identities") {
                    Text("Open Terminal and run:")
                    CommandBlock("security find-identity -p basic -v")
                    Text("You'll see something like:")
                    CommandBlock("""
                      1) 86A4…2A31 "Developer ID Application: Jane Appleseed (ABCDE12345)"
                      2) 42EF…9B42 "Developer ID Installer: Jane Appleseed (ABCDE12345)"
                         2 valid identities found
                    """, copyable: false)
                    Text("Copy the text inside the quotes on the **Developer ID Installer** line and paste it into **Signing identity**. The code in brackets is your Team ID.")
                    Text("Or click the \(Image(systemName: "key")) button next to the field to pick from the identities the app found.")
                }

                HelpSection("Why “-p basic”?") {
                    Text("`-p codesigning` only lists certificates that sign apps and code, so the Installer certificate doesn't show up. `-p basic` lists every identity. `-v` hides expired, revoked and incomplete ones, so only usable identities are shown.")
                    Text("To show just installer identities:")
                    CommandBlock("security find-identity -p basic -v | grep \"Developer ID Installer\"")
                }

                HelpSection("More detail") {
                    Text("See the certificate's full name, team and expiry date:")
                    CommandBlock("security find-certificate -c \"Developer ID Installer\" -p | openssl x509 -noout -subject -enddate")
                    Text("Compare with the list without `-v`. If the certificate appears there but not with `-v`, it has expired, been revoked, or its private key isn't on this Mac:")
                    CommandBlock("security find-identity -p basic")
                    Text("In **Keychain Access**, open **login › My Certificates**. A usable identity has a disclosure triangle with a private key underneath.")
                }

                HelpSection("Don't have one?") {
                    Text("In Xcode, choose **Settings › Accounts**, select your team, click **Manage Certificates…**, then **+ › Developer ID Installer**. Only the Account Holder (or an Admin with access) can create Developer ID certificates. You can also create one at developer.apple.com under **Certificates, Identifiers & Profiles**.")
                    Text("If the certificate was made on another Mac, export it with its private key as a .p12 from that Mac's Keychain Access and import it here.")
                }

                HelpSection("Check and notarize the package") {
                    Text("Confirm the signature on a built package:")
                    CommandBlock("pkgutil --check-signature \"Teams Backgrounds.pkg\"")
                    Text("For packages shared outside your MDM, notarize and staple them too (replace `notary` with your notarytool keychain profile):")
                    CommandBlock("""
                    xcrun notarytool submit "Teams Backgrounds.pkg" --keychain-profile notary --wait
                    xcrun stapler staple "Teams Backgrounds.pkg"
                    """)
                }

                HelpSection("The package identifier") {
                    Text("The identifier is a reverse-DNS name that MDMs and `pkgutil` use to track the install, such as `com.yourcompany.teams-backgrounds`. Keep it the same across versions and raise **Version** each time you deploy new backgrounds.")
                    Text("Choose **Teams Backgrounds › Settings…** to remember your identifier and signing identity between sessions or set defaults.")
                }
            }
            .padding(28)
            .frame(maxWidth: 680, alignment: .leading)
            .textSelection(.enabled)
        }
        .frame(minWidth: 560, idealWidth: 680, minHeight: 480, idealHeight: 720)
    }
}

private struct HelpSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title3.bold())
            content
        }
    }
}

/// A monospaced Terminal command with an optional copy button.
private struct CommandBlock: View {
    let command: String
    var copyable = true

    init(_ command: String, copyable: Bool = true) {
        self.command = command
        self.copyable = copyable
    }

    var body: some View {
        HStack(alignment: .top) {
            Text(command)
                .font(.callout.monospaced())
                .frame(maxWidth: .infinity, alignment: .leading)
            if copyable {
                Button("Copy", systemImage: "doc.on.doc") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(command, forType: .string)
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .help("Copy command")
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 8))
    }
}

#Preview {
    SigningHelpView()
}
