import Foundation

/// Builds the Folder / DMG / PKG output from the queued images.
nonisolated enum PackageBuilder {
    typealias Logger = @MainActor @Sendable (String) -> Void

    private static let commandScriptName = "Install Teams Backgrounds.command"
    private static let pkgScriptName = "install-backgrounds.sh"

    /// Builds the package and returns the URL of the finished artifact.
    @concurrent
    static func build(items: [BackgroundItem], options: BuildOptions, log: Logger) async throws -> URL {
        guard !items.isEmpty else { throw PackagerError.noImages }

        let fileManager = FileManager.default
        let workDirectory = fileManager.temporaryDirectory
            .appending(path: "TeamsBackgrounds-\(UUID().uuidString)", directoryHint: .isDirectory)
        try fileManager.createDirectory(at: workDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: workDirectory) }

        switch options.outputFormat {
        case .folder:
            let output = uniqueURL(in: options.destination, name: options.safeName, pathExtension: nil)
            try await stage(items: items, at: output, scriptName: commandScriptName, includeReadme: true, options: options, log: log)
            return output

        case .dmg:
            let staging = workDirectory.appending(path: options.safeName, directoryHint: .isDirectory)
            try await stage(items: items, at: staging, scriptName: commandScriptName, includeReadme: true, options: options, log: log)

            let output = uniqueURL(in: options.destination, name: options.safeName, pathExtension: "dmg")
            await log("Creating disk image…")
            try await run("/usr/bin/hdiutil", [
                "create",
                "-volname", options.safeName,
                "-srcfolder", staging.path(percentEncoded: false),
                "-format", "UDZO",
                output.path(percentEncoded: false)
            ], log: log)
            return output

        case .pkg:
            // Payload mirrors the target file system; installed relative to "/".
            let payloadRoot = workDirectory.appending(path: "payload", directoryHint: .isDirectory)
            let payloadFolder = payloadRoot.appending(
                path: String(ScriptTemplates.pkgPayloadPath(for: options).dropFirst()),
                directoryHint: .isDirectory
            )
            try await stage(items: items, at: payloadFolder, scriptName: pkgScriptName, includeReadme: false, options: options, log: log)

            let scriptsFolder = workDirectory.appending(path: "scripts", directoryHint: .isDirectory)
            try fileManager.createDirectory(at: scriptsFolder, withIntermediateDirectories: true)
            try writeExecutable(ScriptTemplates.postinstallScript(options: options), to: scriptsFolder.appending(path: "postinstall"))

            let output = uniqueURL(in: options.destination, name: options.safeName, pathExtension: "pkg")
            var arguments = [
                "--root", payloadRoot.path(percentEncoded: false),
                "--scripts", scriptsFolder.path(percentEncoded: false),
                "--identifier", options.packageIdentifier,
                "--version", options.packageVersion,
                "--install-location", "/"
            ]
            let identity = options.signingIdentity.trimmingCharacters(in: .whitespaces)
            if !identity.isEmpty {
                arguments += ["--sign", identity]
            }
            arguments.append(output.path(percentEncoded: false))

            // Strip extended attributes so pkgbuild doesn't add AppleDouble "._" files to the payload.
            try await run("/usr/bin/xattr", ["-cr", payloadRoot.path(percentEncoded: false)], log: log)

            await log("Building installer package…")
            try await run("/usr/bin/pkgbuild", arguments, log: log)
            return output
        }
    }

    /// Creates the folder structure: converted images in `Backgrounds/` plus the install script.
    private static func stage(
        items: [BackgroundItem],
        at folder: URL,
        scriptName: String,
        includeReadme: Bool,
        options: BuildOptions,
        log: Logger
    ) async throws {
        let fileManager = FileManager.default
        let backgrounds = folder.appending(path: "Backgrounds", directoryHint: .isDirectory)
        try fileManager.createDirectory(at: backgrounds, withIntermediateDirectories: true)

        for (index, item) in items.enumerated() {
            try Task.checkCancellation()
            await log("[\(index + 1)/\(items.count)] \(item.sourceURL.lastPathComponent) → \(item.fileName)")
            try ImageConverter.convert(item, into: backgrounds, options: options)
        }

        try writeExecutable(
            ScriptTemplates.installScript(options: options, imageCount: items.count),
            to: folder.appending(path: scriptName)
        )

        if includeReadme {
            try ScriptTemplates.readme(options: options, items: items, scriptName: scriptName)
                .write(to: folder.appending(path: "README.txt"), atomically: true, encoding: .utf8)
        }
    }

    private static func writeExecutable(_ contents: String, to url: URL) throws {
        try contents.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path(percentEncoded: false))
    }

    /// Returns `name.ext` in `folder`, appending " 2", " 3", … rather than overwriting an existing item.
    private static func uniqueURL(in folder: URL, name: String, pathExtension: String?) -> URL {
        func candidate(_ base: String) -> URL {
            let url = folder.appending(path: base, directoryHint: pathExtension == nil ? .isDirectory : .notDirectory)
            return pathExtension.map { url.appendingPathExtension($0) } ?? url
        }

        var url = candidate(name)
        var counter = 2
        while FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
            url = candidate("\(name) \(counter)")
            counter += 1
        }
        return url
    }

    /// Runs a command-line tool, throwing with its output if it exits non-zero.
    private static func run(_ executable: String, _ arguments: [String], log: Logger) async throws {
        let process = Process()
        process.executableURL = URL(filePath: executable)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let output = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        if !output.isEmpty {
            await log(output)
        }
        guard process.terminationStatus == 0 else {
            let name = URL(filePath: executable).lastPathComponent
            throw PackagerError.commandFailed(command: name, output: output)
        }
    }
}
