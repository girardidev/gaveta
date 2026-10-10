import AppKit
import SwiftUI

/// `MenuBarExtra(.window)` only ever grows its panel, so after the content shrinks (folders removed)
/// the content floats in the middle of a taller panel. This keeps the panel's height equal to the
/// SwiftUI content's ideal height, with the top edge fixed under the menu bar.
@MainActor
final class PopoverSizer {
    private weak var window: NSWindow?
    /// The panel's own hosting view reports a zero fitting size, so the ideal height is measured
    /// on a separate hosting view of the same content (backed by the same observable state).
    private let measuringView: NSHostingView<AnyView>
    private var observers: [any NSObjectProtocol] = []

    init(measuring content: AnyView) {
        measuringView = NSHostingView(rootView: content)
    }

    func attach(_ window: NSWindow) {
        guard self.window !== window else { return }
        observers.forEach(NotificationCenter.default.removeObserver)
        self.window = window
        // When the panel is shown, and whenever someone else (SwiftUI) resizes it.
        observers = [NSWindow.didChangeOcclusionStateNotification, NSWindow.didResizeNotification].map { name in
            NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.apply() }
            }
        }
        apply()
    }

    /// Height the panel should have to fit its content.
    var idealContentHeight: CGFloat { measuringView.fittingSize.height }

    func apply() {
        guard let window else { return }
        let contentHeight = idealContentHeight
        guard contentHeight > 0 else { return }
        let contentWidth = window.contentRect(forFrameRect: window.frame).width
        let target = window.frameRect(
            forContentRect: NSRect(x: 0, y: 0, width: contentWidth, height: contentHeight)
        ).height
        guard abs(window.frame.height - target) > 0.5 else { return }

        // Resizing keeps the bottom-left corner; the panel hangs from the menu bar, so keep the top.
        var frame = window.frame
        frame.origin.y = frame.maxY - target
        frame.size.height = target
        window.setFrame(frame, display: true)
    }
}

/// Hands the hosting `NSWindow` to SwiftUI once the view is installed in it.
struct WindowAccessor: NSViewRepresentable {
    let onWindow: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = AccessorView()
        view.onWindow = onWindow
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    final class AccessorView: NSView {
        var onWindow: ((NSWindow) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            DispatchQueue.main.async { [weak self] in self?.onWindow?(window) }
        }
    }
}

extension View {
    /// Keeps the hosting panel exactly as tall as this view's ideal height.
    func fitsHostingPanel(_ sizer: PopoverSizer?) -> some View {
        background(WindowAccessor { sizer?.attach($0) })
    }
}
