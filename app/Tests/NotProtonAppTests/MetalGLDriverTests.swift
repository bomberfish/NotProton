import Foundation
import Testing

@testable import NotProtonApp

// The status page names the installed driver from the GL_VERSION string inside it, which is
// also what a dylib installed by metalgldrv's own scripts carries.
@Suite("metalgldrv version")
struct MetalGLDriverTests {

    private func file(_ bytes: [UInt8]) throws -> URL {
        let url = URL.temporaryDirectory.appending(path: "np-mgl-\(UUID().uuidString).dylib")
        try Data(bytes).write(to: url)
        return url
    }

    @Test("The version follows the core profile string and ends at its NUL")
    func readsVersion() throws {
        let url = try file([0xCF, 0xFA, 0xED, 0xFE, 0]
            + Array("4.6.0 Core Profile metalgldrv 0.1.1".utf8) + [0]
            + Array("4.6.0 Compatibility Profile metalgldrv 0.1.1".utf8) + [0])
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(MetalGLDriver.version(of: url) == "0.1.1")
    }

    @Test("Builds after a release keep their commit suffix")
    func keepsSuffix() throws {
        let url = try file(Array("x4.6.0 Core Profile metalgldrv 0.1.1+3-gabc1234".utf8) + [0, 1, 2])
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(MetalGLDriver.version(of: url) == "0.1.1+3-gabc1234")
    }

    @Test("A file without the string has no version")
    func noVersion() throws {
        let url = try file(Array("not a driver".utf8))
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(MetalGLDriver.version(of: url) == nil)
        #expect(MetalGLDriver.version(of: url.appending(path: "missing")) == nil)
    }
}
