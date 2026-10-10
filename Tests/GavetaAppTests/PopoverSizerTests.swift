import AppKit
import GavetaCore
import SwiftUI
import Testing
@testable import GavetaApp

@MainActor
@Suite("PopoverSizer")
struct PopoverSizerTests {
    let directory = FileManager.default.temporaryDirectory.appending(path: "gaveta-sizer-\(UUID().uuidString)")

    /// A panel like MenuBarExtra's: it starts at 320 pt and hosts the real menu view.
    private func makePanel(folderCount: Int) throws -> (NSWindow, PopoverSizer) {
        let store = FolderStore(fileURL: directory.appending(path: "folders.json"))
        try store.save(FoldersFile(folders: (0..<folderCount).map {
            Folder(path: "/tmp/f\($0)", alias: "folder-\($0)")
        }))
        let observer = FolderObserver(store: store)
        let loginItem = LoginItem()
        let sizer = PopoverSizer(measuring: AnyView(MenuView(observer: observer, loginItem: loginItem, sizer: nil)))
        // Like MenuBarExtra's panel, the window's own hosting view is not used for measuring.
        let hosting = NSHostingView(rootView: AnyView(MenuView(observer: observer, loginItem: loginItem, sizer: nil)))
        let window = NSPanel(
            contentRect: NSRect(x: 100, y: 400, width: 340, height: 320),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false
        )
        window.contentView = hosting
        return (window, sizer)
    }

    @Test func shrinksAPanelThatIsTallerThanItsContentAndKeepsTheTopEdge() throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let (window, sizer) = try makePanel(folderCount: 1)
        let topBefore = window.frame.maxY
        sizer.attach(window)

        let fitting = try #require(window.contentView).fittingSize.height
        #expect(fitting > 0)
        #expect(window.frame.height < 320)
        #expect(abs(window.frame.height - fitting) < 1)
        #expect(window.frame.maxY == topBefore)
        #expect(window.frame.width == 340)
    }

    @Test func tracksTheContentAsFoldersChange() throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        var heights: [CGFloat] = []
        for count in [0, 1, 2, 4] {
            let (window, sizer) = try makePanel(folderCount: count)
            sizer.attach(window)
            heights.append(window.frame.height)
            #expect(abs(window.frame.height - window.contentView!.fittingSize.height) < 1)
        }
        // More folders, taller panel (an empty list shows a hint, so it is not compared).
        #expect(heights[1] < heights[2] && heights[2] < heights[3])
    }

    @Test func growsAPanelThatIsTooShort() throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let (window, sizer) = try makePanel(folderCount: 5)
        window.setFrame(NSRect(x: 100, y: 400, width: 340, height: 100), display: false)
        let topBefore = window.frame.maxY
        sizer.attach(window)
        #expect(window.frame.height > 100)
        #expect(window.frame.maxY == topBefore)
    }

    @Test func correctsLaterResizesByAnyone() throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let (window, sizer) = try makePanel(folderCount: 2)
        sizer.attach(window)
        let ideal = window.frame.height
        window.setFrame(NSRect(x: 100, y: 300, width: 340, height: 500), display: false)
        #expect(abs(window.frame.height - ideal) < 1) // didResize handler put it back
    }
}
