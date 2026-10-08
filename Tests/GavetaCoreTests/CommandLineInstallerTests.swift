import Foundation
import Testing
@testable import GavetaCore

@Suite("CommandLineInstaller")
struct CommandLineInstallerTests {
    let sb: Sandbox
    let target: String
    let linkPath: String

    init() throws {
        sb = try Sandbox()
        target = sb.path("rw/gaveta-bin")
        try "#!/bin/sh\n".write(toFile: target, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: target)
        linkPath = sb.path("bin/gaveta")
    }

    private var installer: CommandLineInstaller { CommandLineInstaller(linkPath: linkPath) }

    @Test func createsTheLinkAndMissingParentDirectory() throws {
        #expect(try installer.install(target: target) == .installed)
        #expect(try FileManager.default.destinationOfSymbolicLink(atPath: linkPath) == target)
    }

    @Test func isIdempotent() throws {
        _ = try installer.install(target: target)
        #expect(try installer.install(target: target) == .alreadyInstalled)
    }

    @Test func replacesAStaleSymlink() throws {
        try FileManager.default.createDirectory(atPath: sb.path("bin"), withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(atPath: linkPath, withDestinationPath: "/nowhere")
        #expect(try installer.install(target: target) == .installed)
        #expect(try FileManager.default.destinationOfSymbolicLink(atPath: linkPath) == target)
    }

    @Test func neverReplacesARegularFile() throws {
        try FileManager.default.createDirectory(atPath: sb.path("bin"), withIntermediateDirectories: true)
        try "mine".write(toFile: linkPath, atomically: true, encoding: .utf8)
        #expect(throws: GavetaError.notASymlink(linkPath)) { try installer.install(target: target) }
        #expect(try String(contentsOfFile: linkPath, encoding: .utf8) == "mine")
        #expect(throws: GavetaError.notASymlink(linkPath)) { try installer.uninstall() }
    }

    @Test func refusesMissingOrNonExecutableTargets() throws {
        #expect(throws: GavetaError.self) { try installer.install(target: sb.path("nope")) }
        #expect(throws: GavetaError.self) { try installer.install(target: sb.path("site/index.html")) }
    }

    @Test func uninstallRemovesOnlyTheSymlink() throws {
        #expect(try installer.uninstall() == false)
        _ = try installer.install(target: target)
        #expect(try installer.uninstall())
        #expect(!FileManager.default.fileExists(atPath: linkPath))
        #expect(FileManager.default.fileExists(atPath: target))
    }

    @Test func suggestsSudoWhenTheDirectoryIsNotWritable() throws {
        try FileManager.default.createDirectory(atPath: sb.path("bin"), withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: sb.path("bin"))
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: sb.path("bin")) }
        do {
            _ = try installer.install(target: target)
            Issue.record("expected a permission error")
        } catch let error as GavetaError {
            guard case .needsAdministrator(let command) = error else { Issue.record("wrong error: \(error)"); return }
            #expect(command.contains("sudo ln -sf"))
        }
    }
}
