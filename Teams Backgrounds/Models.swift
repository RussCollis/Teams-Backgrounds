import Foundation

/// The kind of deployable artifact the packager produces.
nonisolated enum OutputFormat: String, CaseIterable, Identifiable, Sendable {
    case folder = "Folder"
    case dmg = "DMG"
    case pkg = "PKG"

    var id: Self { self }

    var summary: String {
        switch self {
        case .folder: "A folder with the converted images and a double-clickable install script."
        case .dmg: "A disk image with the converted images and a double-clickable install script."
        case .pkg: "An installer package that stages the images in /private/tmp, copies them into Teams in a postinstall step, then cleans up (suitable for MDM / Intune)."
        }
    }
}

/// Pixel size the full-size backgrounds are rendered at.
nonisolated enum OutputResolution: String, CaseIterable, Identifiable, Sendable {
    case fullHD = "1920 × 1080"
    case quadHD = "2560 × 1440"
    case ultraHD = "3840 × 2160"

    var id: Self { self }

    var width: Int {
        switch self {
        case .fullHD: 1920
        case .quadHD: 2560
        case .ultraHD: 3840
        }
    }

    var height: Int {
        switch self {
        case .fullHD: 1080
        case .quadHD: 1440
        case .ultraHD: 2160
        }
    }
}

/// How a source image is fitted into the output resolution.
nonisolated enum ResizeMode: String, CaseIterable, Identifiable, Sendable {
    case fill = "Fill (crop to 16:9)"
    case fit = "Fit (letterbox)"
    case original = "Keep original size"

    var id: Self { self }
}

/// Which Teams client(s) the install script targets.
nonisolated enum TeamsTarget: String, CaseIterable, Identifiable, Sendable {
    case both = "New & Classic Teams"
    case new = "New Teams only"
    case classic = "Classic Teams only"

    var id: Self { self }

    var includesNew: Bool { self != .classic }
    var includesClassic: Bool { self != .new }
}

/// A source image queued for packaging. Its `id` becomes the Teams file name.
nonisolated struct BackgroundItem: Identifiable, Hashable, Sendable {
    let id: UUID
    let sourceURL: URL

    init(sourceURL: URL) {
        self.id = UUID()
        self.sourceURL = sourceURL
    }

    /// Teams expects lowercase UUID names, e.g. `898ffbba-....png`.
    var baseName: String { id.uuidString.lowercased() }
    var fileName: String { "\(baseName).png" }
    var thumbnailFileName: String { "\(baseName)_thumb.png" }
}

/// Everything the builder needs to produce a package.
nonisolated struct BuildOptions: Sendable {
    var packageName: String
    var outputFormat: OutputFormat
    var destination: URL
    var resolution: OutputResolution
    var resizeMode: ResizeMode
    var teamsTarget: TeamsTarget
    var restartTeams: Bool
    var installForAllUsers: Bool
    var packageIdentifier: String
    var packageVersion: String
    var signingIdentity: String

    /// The package name made safe for use as a file / folder name.
    var safeName: String {
        let invalid = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let cleaned = packageName
            .components(separatedBy: invalid)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Teams Backgrounds" : cleaned
    }
}

nonisolated enum PackagerError: LocalizedError {
    case unreadableImage(URL)
    case renderFailed(URL)
    case writeFailed(URL)
    case commandFailed(command: String, output: String)
    case noImages

    var errorDescription: String? {
        switch self {
        case .unreadableImage(let url): "Couldn't read image \(url.lastPathComponent)."
        case .renderFailed(let url): "Couldn't convert image \(url.lastPathComponent)."
        case .writeFailed(let url): "Couldn't write \(url.lastPathComponent)."
        case .commandFailed(let command, let output): "\(command) failed:\n\(output)"
        case .noImages: "Add at least one image first."
        }
    }
}
