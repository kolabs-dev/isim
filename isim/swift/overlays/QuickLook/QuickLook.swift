// isim QuickLook Swift overlay (issue #237): SwiftUI's quickLookPreview modifiers, which present a QLPreviewController
// over a URL or a collection of URLs and clear the binding when it is dismissed (Apple declares them in the QuickLook
// module, available with SwiftUI).
@_exported import QuickLook
import SwiftUI
import UIKit

@MainActor final class _QLPreviewPresenter: NSObject, @preconcurrency QLPreviewControllerDataSource, @preconcurrency QLPreviewControllerDelegate {
    var urls: [URL] = []
    var dismissed: () -> Void = {}
    weak var controller: QLPreviewController?

    func numberOfPreviewItems(in controller: QLPreviewController) -> Int { urls.count }
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem { urls[index] as QLPreviewItem }
    func previewControllerDidDismiss(_ controller: QLPreviewController) { self.controller = nil; dismissed() }

    static func top() -> UIViewController? {
        let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
        var top = (windows.first { $0.isKeyWindow } ?? windows.first)?.rootViewController
        while let p = top?.presentedViewController { top = p }
        return top
    }
    /// shows `urls` from `index`, or dismisses when `urls` is empty
    func update(urls: [URL], index: Int?) {
        guard let index, !urls.isEmpty else {
            if let c = controller { controller = nil; c.dismiss(animated: true) }
            return
        }
        self.urls = urls
        if let c = controller {
            c.reloadData()
            c.currentPreviewItemIndex = index
            return
        }
        guard let top = _QLPreviewPresenter.top() else { return }
        let c = QLPreviewController()
        c.dataSource = self; c.delegate = self
        c.currentPreviewItemIndex = index
        controller = c
        top.present(c, animated: true)
    }
}

struct _QuickLookPreviewModifier: ViewModifier {
    let urls: [URL]
    let index: Int?
    let clear: () -> Void
    @State private var presenter = _QLPreviewPresenter()

    func body(content: Content) -> some View {
        content
            .onAppear { show() }
            .onChange(of: index) { _, _ in show() }
    }
    func show() {
        presenter.dismissed = clear
        presenter.update(urls: urls, index: index)
    }
}

extension View {
    /// Presents a Quick Look preview of the URL; setting the binding to nil (or Done) dismisses it.
    public func quickLookPreview(_ item: Binding<URL?>) -> some View {
        modifier(_QuickLookPreviewModifier(urls: item.wrappedValue.map { [$0] } ?? [], index: item.wrappedValue == nil ? nil : 0,
                                           clear: { item.wrappedValue = nil }))
    }
    /// Presents a Quick Look preview of the items, starting at the selected one; swiping moves between them.
    public func quickLookPreview<Items>(_ selection: Binding<Items.Element?>, in items: Items) -> some View
    where Items: RandomAccessCollection, Items.Element == URL {
        let urls = Array(items)
        let index = selection.wrappedValue.flatMap { urls.firstIndex(of: $0) }
        return modifier(_QuickLookPreviewModifier(urls: urls, index: index, clear: { selection.wrappedValue = nil }))
    }
}
