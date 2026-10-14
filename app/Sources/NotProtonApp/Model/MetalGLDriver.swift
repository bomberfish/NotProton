// metalgldrv: OpenGL 4.6 on Metal in place of Apple's OpenGL 4.1, turned on per game
// (Properties > Compatibility > OpenGL). compat_run.sh injects it from the path below.

import Foundation

enum MetalGLDriver {

    static let step = String(localized: "Install metalgldrv")
    static let repository = "bomberfish/metalgldrv"
    static let asset = "libmetalgldrv-macos-universal.zip"

    // Shared with metalgldrv's own install scripts, so either one updates the same file.
    static var directory: URL { SupportPaths.applicationSupport.appending(path: "metalgldrv") }
    static var dylib: URL { directory.appending(path: "libmetalgldrv.dylib") }

    struct Installed: Sendable, Equatable {
        var version: String?
    }

    static func installed() -> Installed? {
        guard FileManager.default.fileExists(atPath: dylib.path(percentEncoded: false)) else { return nil }
        return Installed(version: version(of: dylib))
    }

    // The driver names itself in its GL_VERSION string ("4.6.0 Core Profile metalgldrv 0.1.1").
    static func version(of url: URL) -> String? {
        guard let data = try? Data(contentsOf: url, options: .alwaysMapped) else { return nil }
        let marker = Data("Core Profile metalgldrv ".utf8)
        guard let found = data.range(of: marker) else { return nil }
        let rest = data[found.upperBound...].prefix(64)
        let end = rest.firstIndex(of: 0) ?? rest.endIndex
        let version = String(decoding: rest[..<end], as: UTF8.self)
        return version.isEmpty ? nil : version
    }

    // Installs the latest release; returns its version.
    static func install(progress: @Sendable (String) -> Void) async throws -> String {
        progress(String(localized: "Looking for the latest metalgldrv"))
        let tag = try await latestTag()

        let base = URL(string: "https://github.com/\(repository)/releases/download/\(tag)/")!
        progress(String(localized: "Downloading metalgldrv \(tag)"))
        let zip = try await download(base.appending(path: asset))
        defer { try? FileManager.default.removeItem(at: zip) }
        let sums = try await download(base.appending(path: asset + ".sha256"))
        defer { try? FileManager.default.removeItem(at: sums) }

        let expected = String(decoding: try Data(contentsOf: sums), as: UTF8.self)
            .split(whereSeparator: \.isWhitespace).first.map(String.init) ?? ""
        guard try Digest.sha256(of: zip) == expected.lowercased() else {
            throw StepFailure(step: step, detail: String(localized: "The downloaded metalgldrv does not match its checksum."))
        }

        let unpacked = FileManager.default.temporaryDirectory.appending(path: "metalgldrv-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: unpacked) }
        try Shell.check("/usr/bin/ditto", ["-x", "-k", zip.path(percentEncoded: false), unpacked.path(percentEncoded: false)])
        let fresh = unpacked.appending(path: "libmetalgldrv.dylib")
        guard FileManager.default.fileExists(atPath: fresh.path(percentEncoded: false)) else {
            throw StepFailure(step: step, detail: String(localized: "The metalgldrv download has no libmetalgldrv.dylib."))
        }

        // A new file rather than a rewrite: games already running keep the copy they loaded.
        try atomicReplace(dylib, from: fresh, step: step)
        return version(of: dylib) ?? tag
    }

    // Leaves the folder and metalgldrv.conf, which hold the user's driver settings.
    static func remove() throws {
        do {
            try FileManager.default.removeItem(at: dylib)
        } catch CocoaError.fileNoSuchFile {
        } catch {
            throw StepFailure(step: String(localized: "Remove metalgldrv"), detail: error.localizedDescription)
        }
    }

    private static func latestTag() async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let data: Data, response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw StepFailure(step: step, detail: String(localized: "GitHub could not be reached. \(error.localizedDescription)"))
        }
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let release = try? JSONDecoder().decode(Release.self, from: data),
              release.tagName.allSatisfy({ $0.isLetter || $0.isNumber || ".-_".contains($0) }) else {
            throw StepFailure(step: step, detail: String(localized: "No metalgldrv release was found on GitHub."))
        }
        return release.tagName
    }

    private struct Release: Decodable {
        let tagName: String
        enum CodingKeys: String, CodingKey { case tagName = "tag_name" }
    }

    private static func download(_ url: URL) async throws -> URL {
        let (file, response): (URL, URLResponse)
        do {
            (file, response) = try await URLSession.shared.download(from: url)
        } catch {
            throw StepFailure(step: step, detail: String(localized: "GitHub could not be reached. \(error.localizedDescription)"))
        }
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            try? FileManager.default.removeItem(at: file)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw StepFailure(step: step, detail: String(localized: "GitHub answered \(code) for \(url.lastPathComponent)."))
        }
        return file
    }
}
