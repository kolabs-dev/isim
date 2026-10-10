// isim SwiftUI: drag and drop — .draggable / .dropDestination (Transferable), .onDrag / .onDrop (NSItemProvider),
// built on UIKit's UIDragInteraction / UIDropInteraction on the mounted views (long press to lift).
import UIKit
import UniformTypeIdentifiers
import CoreTransferable

nonisolated(unsafe) private var kSUIDrag: UInt8 = 0, kSUIDrop: UInt8 = 0

final class _SUIDragSource: NSObject, UIDragInteractionDelegate {
    var make: () -> NSItemProvider
    /// a custom preview (`preview:`): a SwiftUI view shown under the finger instead of the view itself
    var preview: (@MainActor () -> AnyView)?
    var previewHost: UIViewController?                     // (keeps the preview's hosting controller alive)
    init(_ make: @escaping () -> NSItemProvider) { self.make = make }
    func dragInteraction(_ interaction: UIDragInteraction, itemsForBeginning session: UIDragSession) -> [UIDragItem] { [UIDragItem(itemProvider: make())] }
    func dragInteraction(_ interaction: UIDragInteraction, previewForLifting item: UIDragItem, session: UIDragSession) -> UITargetedDragPreview? {
        guard let make = preview, let source = interaction.view else { return nil }
        return MainActor.assumeIsolated {
            let host = UIHostingController(rootView: make())
            previewHost = host
            let size = host.sizeThatFits(in: CGSize(width: 400, height: 400))
            host.view.frame = CGRect(origin: .zero, size: size)
            host.view.backgroundColor = .clear
            host.view.accessibilityIdentifier = "isim-drag-custom-preview"
            let target = UIPreviewTarget(container: source, center: CGPoint(x: source.bounds.midX, y: source.bounds.midY))
            return UITargetedDragPreview(view: host.view, parameters: UIDragPreviewParameters(), target: target)
        }
    }
}
final class _SUIDropTarget: NSObject, UIDropInteractionDelegate {
    var types: [UTType]
    var targeted: ((Bool) -> Void)?
    var perform: ([NSItemProvider], CGPoint) -> Bool
    init(types: [UTType], targeted: ((Bool) -> Void)?, perform: @escaping ([NSItemProvider], CGPoint) -> Bool) { self.types = types; self.targeted = targeted; self.perform = perform }
    func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool { session.hasItemsConforming(toTypeIdentifiers: types.map(\.identifier)) }
    func dropInteraction(_ interaction: UIDropInteraction, sessionDidEnter session: UIDropSession) { targeted?(true) }
    func dropInteraction(_ interaction: UIDropInteraction, sessionDidExit session: UIDropSession) { targeted?(false) }
    func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal { UIDropProposal(operation: .copy) }
    func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
        targeted?(false)
        let p = interaction.view.map { session.location(in: $0) } ?? .zero
        _ = perform(session.items.map(\.itemProvider), p)
    }
}

@MainActor func _installDrag(_ v: UIView, _ make: @escaping () -> NSItemProvider, preview: (@MainActor () -> AnyView)? = nil) {
    if let src = objc_getAssociatedObject(v, &kSUIDrag) as? _SUIDragSource { src.make = make; src.preview = preview; return }
    let src = _SUIDragSource(make)
    src.preview = preview
    objc_setAssociatedObject(v, &kSUIDrag, src, objc_AssociationPolicy(OBJC_ASSOCIATION_RETAIN_NONATOMIC))
    v.addInteraction(UIDragInteraction(delegate: src))
    v.isUserInteractionEnabled = true
}
@MainActor func _installDrop(_ v: UIView, _ t: _SUIDropTarget) {
    if let old = objc_getAssociatedObject(v, &kSUIDrop) as? _SUIDropTarget { old.types = t.types; old.targeted = t.targeted; old.perform = t.perform; return }
    objc_setAssociatedObject(v, &kSUIDrop, t, objc_AssociationPolicy(OBJC_ASSOCIATION_RETAIN_NONATOMIC))
    v.addInteraction(UIDropInteraction(delegate: t))
}

/// An item provider with the payload's exported representations
func _provider<T: Transferable>(_ payload: T) -> NSItemProvider {
    let p = NSItemProvider()
    let box = _UncheckedSendable(payload)
    for t in T.exportedContentTypes {
        p.registerDataRepresentation(forTypeIdentifier: t.identifier, visibility: .all) { done in
            let sem = DispatchSemaphore(value: 0)
            nonisolated(unsafe) var data: Data?, err: Error?
            Task.detached { do { data = try await box.value.exported(as: t) } catch { err = error }; sem.signal() }
            sem.wait()
            done(data, err)
            return nil
        }
    }
    return p
}
struct _UncheckedSendable<T>: @unchecked Sendable { let value: T; init(_ v: T) { value = v } }

extension View {
    public func onDrag(_ data: @escaping () -> NSItemProvider) -> some View {
        _accessibility(deepest: false) { v in _installDrag(v, data) }
    }
    /// With a custom drag preview (the view shown under the finger).
    public func onDrag<V: View>(_ data: @escaping () -> NSItemProvider, preview: () -> V) -> some View {
        let p = AnyView(preview())
        return _accessibility(deepest: false) { v in _installDrag(v, data, preview: { p }) }
    }
    public func onDrop(of types: [UTType], isTargeted: Binding<Bool>?, perform action: @escaping ([NSItemProvider]) -> Bool) -> some View {
        onDrop(of: types, isTargeted: isTargeted) { providers, _ in action(providers) }
    }
    public func onDrop(of types: [UTType], isTargeted: Binding<Bool>?, perform action: @escaping ([NSItemProvider], CGPoint) -> Bool) -> some View {
        let target = _SUIDropTarget(types: types, targeted: isTargeted.map { b in { b.wrappedValue = $0 } }, perform: action)
        return _accessibility(deepest: false) { v in _installDrop(v, target) }
    }
    public func onDrop(of types: [String], isTargeted: Binding<Bool>?, perform action: @escaping ([NSItemProvider]) -> Bool) -> some View {
        onDrop(of: types.compactMap { UTType($0) }, isTargeted: isTargeted, perform: action)
    }
    public func draggable<T: Transferable>(_ payload: @autoclosure @escaping () -> T) -> some View {
        onDrag { _provider(payload()) }
    }
    public func draggable<T: Transferable, V: View>(_ payload: @autoclosure @escaping () -> T, preview: () -> V) -> some View {
        onDrag({ _provider(payload()) }, preview: preview)
    }
    public func dropDestination<T: Transferable>(for payloadType: T.Type = T.self, action: @escaping ([T], CGPoint) -> Bool,
                                                isTargeted: @escaping (Bool) -> Void = { _ in }) -> some View {
        let types = T.importedContentTypes
        let target = _SUIDropTarget(types: types, targeted: isTargeted) { providers, point in
            let group = DispatchGroup(), lock = NSLock()
            nonisolated(unsafe) var out: [(Int, T)] = []
            for (i, p) in providers.enumerated() {
                guard let t = types.first(where: { p.hasItemConformingToTypeIdentifier($0.identifier) }) else { continue }
                group.enter()
                p.loadDataRepresentation(forTypeIdentifier: t.identifier) { data, _ in
                    guard let data else { group.leave(); return }
                    Task.detached {
                        if let v = try? await T._isimImport(data, contentType: t) { lock.lock(); out.append((i, v)); lock.unlock() }
                        group.leave()
                    }
                }
            }
            let box = _UncheckedSendable(action)
            group.notify(queue: .main) { _ = box.value(out.sorted { $0.0 < $1.0 }.map(\.1), point) }
            return true
        }
        return _accessibility(deepest: false) { v in _installDrop(v, target) }
    }
}
