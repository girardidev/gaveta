import AppKit
import SwiftUI

@main
struct GavetaApp: App {
    @State private var observer = FolderObserver()
    @State private var loginItem = LoginItem()

    init() {
        // No Dock icon, also when running outside an app bundle.
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuView(observer: observer, loginItem: loginItem)
        } label: {
            Image(systemName: "tray.full")
        }
        .menuBarExtraStyle(.window)
    }
}
