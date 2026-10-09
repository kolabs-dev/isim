// isim Foundation: NSItemProvider with Swift's bridged types (String, URL), as on iOS. The class is Objective-C
// (frameworks/Foundation/ItemProvider.m); the UTType conveniences are in UniformTypeIdentifiers.

struct _IsimSendableBox<T>: @unchecked Sendable { let value: T }

extension NSItemProvider {
    /// loads a bridged value (String, URL) through its Objective-C class
    @discardableResult
    public func loadObject<T: _ObjectiveCBridgeable>(ofClass aClass: T.Type, completionHandler: @escaping @Sendable (T?, Error?) -> Void) -> Progress
        where T._ObjectiveCType: NSItemProviderReading {
        let cls = T._ObjectiveCType.self as NSItemProviderReading.Type
        return __loadObject(ofClass: cls) { object, error in
            guard let o = object as? T._ObjectiveCType else { completionHandler(nil, error); return }
            completionHandler(_IsimSendableBox(value: T._unconditionallyBridgeFromObjectiveC(o)).value, nil)
        }
    }
    public func canLoadObject<T: _ObjectiveCBridgeable>(ofClass aClass: T.Type) -> Bool where T._ObjectiveCType: NSItemProviderReading {
        canLoadObject(ofClass: T._ObjectiveCType.self as NSItemProviderReading.Type)
    }
    /// loads an Objective-C object
    @discardableResult
    public func loadObject(ofClass aClass: NSItemProviderReading.Type, completionHandler: @escaping @Sendable (NSItemProviderReading?, Error?) -> Void) -> Progress {
        __loadObject(ofClass: aClass) { object, error in completionHandler(object, error) }
    }
    /// an Objective-C object of a class, made on request
    public func registerObject(ofClass aClass: NSItemProviderWriting.Type, visibility: NSItemProviderRepresentationVisibility,
                               loadHandler: @escaping @Sendable (@escaping @Sendable (NSItemProviderWriting?, Error?) -> Void) -> Progress?) {
        __registerObject(ofClass: aClass, visibility: visibility) { done in loadHandler { o, e in done(o, e) } }
    }
    public func registerObject<T: _ObjectiveCBridgeable>(ofClass aClass: T.Type, visibility: NSItemProviderRepresentationVisibility,
                                                         loadHandler: @escaping @Sendable (@escaping @Sendable (T?, Error?) -> Void) -> Progress?)
        where T._ObjectiveCType: NSItemProviderWriting {
        __registerObject(ofClass: T._ObjectiveCType.self as NSItemProviderWriting.Type, visibility: visibility) { done in
            loadHandler { value, error in done(value.map { $0._bridgeToObjectiveC() as NSItemProviderWriting }, error) }
        }
    }
}
