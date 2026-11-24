import Foundation

/// Finds the "Developer ID Installer" identities in the user's keychains.
nonisolated enum SigningIdentities {
    /// Runs `security find-identity -p basic -v` and returns the installer identity names.
    ///
    /// The `basic` policy is needed because `-p codesigning` leaves out installer certificates.
    @concurrent
    static func installerIdentities() async -> [String] {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/security")
        process.arguments = ["find-identity", "-p", "basic", "-v"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return []
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return installerIdentities(in: String(decoding: data, as: UTF8.self))
    }

    /// Pulls the quoted names out of lines like
    /// `1) 42EF…9B42 "Developer ID Installer: Jane Appleseed (ABCDE12345)"`.
    static func installerIdentities(in output: String) -> [String] {
        var names: [String] = []
        for line in output.split(separator: "\n") {
            guard let start = line.firstIndex(of: "\""),
                  let end = line.lastIndex(of: "\""),
                  start < end else { continue }
            let name = String(line[line.index(after: start)..<end])
            if name.hasPrefix("Developer ID Installer"), !names.contains(name) {
                names.append(name)
            }
        }
        return names
    }
}
