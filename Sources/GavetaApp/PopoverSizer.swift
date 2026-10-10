import AppKit
import SwiftUI

/// `MenuBarExtra(.window)` creates its panel at 320 pt and only ever grows it, so with fewer folders
/// the content floats in the middle of a taller panel. This keeps the panel's height equal to the
/// SwiftUI content's ideal height, with the top edge fixed under the menu bar.
@MainActor
final class PopoverSizer {
    private weak var window: NSWindow?
    /// The panel's own hosting view reports a zero fitting size, so the ideal height is measured
    /// on a separate hosting view of the same content (backed by the same observable state).
    private let measuringView: NSHostingView<AnyView>
    /// Where the panel's top edge belongs. Hosting views resize their window anchored at the
    /// bottom, so the top is remembered when the panel opens instead of read after the fact.
    private var anchoredTop: CGFloat?
    private var isApplying = false
    private let debug = ProcessInfo.processInfo.environment["GAVETA_DEBUG_SIZER"] != nil
    private var observers: [any NSObjectProtocol] = []

    init(measuring content: AnyView) {
        measuringView = NSHostingView(rootView: content)
    }

    func attach(_ window: NSWindow) {
        guard self.window !== window else { return }
        observers.forEach(NotificationCenter.default.removeObserver)
        self.window = window
        anchoredTop = window.frame.maxY
        log("attach \(type(of: window)) frame=\(window.frame) contentView=\(window.contentView.map { String(describing: type(of: $0)) } ?? "nil")")

        // Re-apply whenever the panel opens or is resized by someone else (SwiftUI, AppKit).
        let openEvents: [Notification.Name] = [NSWindow.didBecomeKeyNotification, NSWindow.didChangeOcclusionStateNotification]
        observers = openEvents.map { name in
            NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    // The system has just positioned the panel under the status item.
                    self?.anchoredTop = self?.window?.frame.maxY
                    self?.apply()
                }
            }
        }
        observers.append(
            NotificationCenter.default.addObserver(forName: NSWindow.didResizeNotification, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.apply() }
            }
        )
        apply()
    }

    func apply() {
        guard !isApplying, let window else { return }
        isApplying = true
        defer { isApplying = false }

        let top = anchoredTop ?? window.frame.maxY
        let contentHeight = measuringView.fittingSize.height
        log("apply window=\(window.frame.height) ideal=\(contentHeight)")
        guard contentHeight > 0 else { return }
        let contentWidth = window.contentRect(forFrameRect: window.frame).width
        let targetHeight = window.frameRect(
            forContentRect: NSRect(x: 0, y: 0, width: contentWidth, height: contentHeight)
        ).height

        var frame = window.frame
        frame.size.height = targetHeight
        frame.origin.y = top - targetHeight
        guard abs(window.frame.height - frame.height) > 0.5 || abs(window.frame.origin.y - frame.origin.y) > 0.5 else { return }
        log("resize \(window.frame) -> \(frame) (content \(contentHeight))")
        window.setFrame(frame, display: true)
    }

    private func log(_ message: String) {
        guard debug else { return }
        FileHandle.standardError.write(Data("gaveta sizer: \(message)\n".utf8))
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
