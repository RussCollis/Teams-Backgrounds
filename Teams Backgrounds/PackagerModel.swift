import AppKit
import Observation
import UniformTypeIdentifiers

/// UI state for the packager window.
@Observable
final class PackagerModel {
    var items: [BackgroundItem] = []

    var packageName = "Teams Backgrounds"
    var outputFormat: OutputFormat = .pkg
    var destination: URL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
        ?? FileManager.default.homeDirectoryForCurrentUser
    var resolution: OutputResolution = .fullHD
    var resizeMode: ResizeMode = .fill
    var teamsTarget: TeamsTarget = .both
    var restartTeams = true
    var installForAllUsers = true
    var packageIdentifier = "com.company.teams-backgrounds"
    var packageVersion = "1.0"
    var signingIdentity = ""

    private(set) var isBuilding = false
    private(set) var logLines: [String] = []
    private(set) var lastOutput: URL?
    var errorMessage: String?

    var canBuild: Bool { !items.isEmpty && !isBuilding }

    /// Adds image files, expanding any folders, and skips duplicates and non-images.
    func add(_ urls: [URL]) {
        let existing = Set(items.map(\.sourceURL.standardizedFileURL))
        let newURLs = urls
            .flatMap { Self.imageURLs(in: $0) }
            .map(\.standardizedFileURL)
        var seen = existing
        for url in newURLs where seen.insert(url).inserted {
            items.append(BackgroundItem(sourceURL: url))
        }
    }

    func remove(_ item: BackgroundItem) {
        items.removeAll { $0.id == item.id }
    }

    func removeAll() {
        items.removeAll()
    }

    func chooseImages() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .folder]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.message = "Choose images (or folders of images) to use as Teams backgrounds"
        if panel.runModal() == .OK {
            add(panel.urls)
        }
    }

    func chooseDestination() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.directoryURL = destination
        panel.prompt = "Choose"
        if panel.runModal() == .OK, let url = panel.url {
            destination = url
        }
    }

    func revealOutput() {
        guard let lastOutput else { return }
        NSWorkspace.shared.activateFileViewerSelecting([lastOutput])
    }

    func build() async {
        guard canBuild else { return }
        isBuilding = true
        logLines = []
        lastOutput = nil
        defer { isBuilding = false }

        let options = BuildOptions(
            packageName: packageName,
            outputFormat: outputFormat,
            destination: destination,
            resolution: resolution,
            resizeMode: resizeMode,
            teamsTarget: teamsTarget,
            restartTeams: restartTeams,
            installForAllUsers: installForAllUsers,
            packageIdentifier: packageIdentifier,
            packageVersion: packageVersion,
            signingIdentity: signingIdentity
        )

        do {
            let output = try await PackageBuilder.build(items: items, options: options) { [weak self] line in
                self?.logLines.append(line)
            }
            lastOutput = output
            logLines.append("✅ Created \(output.path(percentEncoded: false))")
        } catch {
            logLines.append("❌ \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    /// Returns the URL itself if it's an image, or all images inside it if it's a folder.
    private static func imageURLs(in url: URL) -> [URL] {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .contentTypeKey])
        if values?.isDirectory == true {
            let enumerator = FileManager.default.enumerator(
                at: url,
                includingPropertiesForKeys: [.contentTypeKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            )
            let children = (enumerator?.allObjects as? [URL]) ?? []
            return children.filter { isImage($0) }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        }
        return isImage(url) ? [url] : []
    }

    private static func isImage(_ url: URL) -> Bool {
        let type = (try? url.resourceValues(forKeys: [.contentTypeKey]))?.contentType
            ?? UTType(filenameExtension: url.pathExtension)
        return type?.conforms(to: .image) ?? false
    }
}
