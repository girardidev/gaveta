import AppKit
import SwiftUI

@main
struct GavetaApp: App {
    @State private var observer: FolderObserver
    @State private var loginItem: LoginItem
    @State private var sizer: PopoverSizer

    init() {
        // No Dock icon, also when running outside an app bundle.
        NSApplication.shared.setActivationPolicy(.accessory)

        let observer = FolderObserver()
        let loginItem = LoginItem()
        _observer = State(initialValue: observer)
        _loginItem = State(initialValue: loginItem)
        _sizer = State(initialValue: PopoverSizer(
            measuring: AnyView(MenuView(observer: observer, loginItem: loginItem, sizer: nil))
        ))
    }

    var body: some Scene {
        MenuBarExtra {
            MenuView(observer: observer, loginItem: loginItem, sizer: sizer)
        } label: {
            Image(systemName: "tray.full")
        }
        .menuBarExtraStyle(.window)
    }
}
