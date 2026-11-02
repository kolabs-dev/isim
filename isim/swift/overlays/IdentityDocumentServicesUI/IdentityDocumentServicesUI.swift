// isim IdentityDocumentServicesUI (iOS 26; issue #744, adapted): the presentment of mobile documents to websites.
// IdentityDocumentWebPresentmentController.performRequests shows isim's system sheet with the registered documents of the
// installed provider apps (IdentityDocumentServices' store) whose type the request asks for. Choosing one runs that
// app's identity document provider extension (EXExtensionPointIdentifier
// com.apple.identity-document-services.document-provider-ui, proposed: Apple does not document it) in this process, like
// isim's other extensions: its ISO18013MobileDocumentRequestScene is shown in a sheet with an
// ISO18013MobileDocumentRequestContext, and the response its sendResponse handler builds for the caller's raw request
// (IdentityDocumentWebPresentmentControllerDelegate) is what performRequests returns. cancel() or dismissing the sheets
// throws IdentityDocumentPresentmentError.cancelled. isim calls the provider's performRegistrationUpdates() when it loads
// the extension. ISIM_IDENTITY_DOCUMENT answers the document sheet without it (a document identifier, or "cancel").
// Apple's framework is Swift only.
import Foundation
import SwiftUI
import UIKit
import ExtensionFoundation
import ExtensionKit
import IdentityDocumentServices

@available(iOS 26.0, *)
public typealias IdentityDocumentPresentationAnchor = UIWindow

/// a controller the system uses for identity document presentment (closed: only isim's controllers conform)
@available(iOS 26.0, *)
@MainActor public protocol IdentityDocumentPresentmentControlling {}

@available(iOS 26.0, *)
@MainActor public protocol IdentityDocumentPresentmentControllerPresentationContextProviding: AnyObject {
    func presentationAnchorForPresentmentController(_ presentmentController: any IdentityDocumentPresentmentControlling) -> IdentityDocumentPresentationAnchor?
}

@available(iOS 26.0, *)
@MainActor public protocol IdentityDocumentWebPresentmentControllerDelegate: AnyObject {
    /// the website's raw requests, which the provider's response is built for
    func rawRequestsForWebPresentmentController(_ webPresentmentController: IdentityDocumentWebPresentmentController) async -> [IdentityDocumentWebPresentmentRawRequest]
}

// MARK: - the controller

@available(iOS 26.0, *)
@MainActor public final class IdentityDocumentWebPresentmentController: IdentityDocumentPresentmentControlling {
    public weak var delegate: (any IdentityDocumentWebPresentmentControllerDelegate)?
    public weak var presentationContextProvider: (any IdentityDocumentPresentmentControllerPresentationContextProviding)?
    private static var inProgress = false
    public init() {}

    public func performRequests(_ requests: [any IdentityDocumentWebPresentmentRequest], origin: URL) async throws -> any IdentityDocumentWebPresentmentResponse {
        guard !Self.inProgress else { throw IdentityDocumentPresentmentError(code: .requestInProgress, debugDescription: "a presentment is already in progress") }
        guard let request = requests.compactMap({ $0 as? ISO18013MobileDocumentRequest }).first else {
            throw IdentityDocumentPresentmentError(code: .invalidRequest, debugDescription: "no ISO 18013 mobile document request")
        }
        guard origin.scheme == "https" else { throw IdentityDocumentPresentmentError(code: .invalidRequest, debugDescription: "the origin must be https") }
        Self.inProgress = true
        defer { Self.inProgress = false }
        let raw = await delegate?.rawRequestsForWebPresentmentController(self).first { $0.requestType == .iso18013MobileDocument }
            ?? IdentityDocumentWebPresentmentRawRequest(requestType: .iso18013MobileDocument, requestData: Data())
        let wanted = Set(request.presentmentRequests.flatMap { $0.documentRequestSets.flatMap { $0.requests.map(\.documentType) } })
        let documents = _IDDocuments.registered().filter { wanted.contains($0.registration.mobileDocumentType) }
        NSLog("isim IdentityDocumentServicesUI: %@ asks for %@; %d registered document(s) match", origin.host ?? "?", wanted.sorted().joined(separator: ", "), documents.count)
        let anchor = presentationContextProvider?.presentationAnchorForPresentmentController(self)
        guard let chosen = await _IDSheets.choose(documents, request: request, origin: origin, anchor: anchor) else {
            throw IdentityDocumentPresentmentError(code: .cancelled, debugDescription: "the person did not choose a document")
        }
        NSLog("isim IdentityDocumentServicesUI: presenting %@ from %@", chosen.registration.documentIdentifier, chosen.appName)
        guard let scene = _IDProviderHost.scene(chosen.extensionPath) else {
            throw IdentityDocumentPresentmentError(code: .unknown, debugDescription: "the provider app has no ISO 18013 mobile document request scene")
        }
        return try await _IDSheets.present(scene, request: request, raw: raw, origin: origin, anchor: anchor)
    }
}

// MARK: - the provider extension

@available(iOS 26.0, *)
@MainActor @preconcurrency public protocol IdentityDocumentRequestScene: AppExtensionScene {
    /// the mobile document scenes a builder combined (isim)
    var _isimMobileDocumentScenes: [_IDMobileDocumentScene] { get }
}

/// a type-erased ISO 18013 mobile document scene (isim)
@available(iOS 26.0, *)
public struct _IDMobileDocumentScene: Sendable {
    let view: @MainActor @Sendable (ISO18013MobileDocumentRequestContext) -> AnyView
}

@available(iOS 26.0, *)
@MainActor @preconcurrency public struct ISO18013MobileDocumentRequestScene<Content>: IdentityDocumentRequestScene where Content: Sendable, Content: View {
    let content: (ISO18013MobileDocumentRequestContext) -> Content
    @MainActor @preconcurrency public init(@ViewBuilder content: @escaping (ISO18013MobileDocumentRequestContext) -> Content) { self.content = content }
    public var _isimMobileDocumentScenes: [_IDMobileDocumentScene] {
        nonisolated(unsafe) let content = self.content
        return [_IDMobileDocumentScene { AnyView(content($0)) }]
    }
}

/// the request a provider's scene answers
@available(iOS 26.0, *)
public struct ISO18013MobileDocumentRequestContext: @unchecked Sendable {
    public let request: ISO18013MobileDocumentRequest
    public let requestingWebsiteOrigin: URL?
    let session: _IDSession
    /// ends the request: the website gets IdentityDocumentPresentmentError.cancelled
    public func cancel() { session.finish(.failure(IdentityDocumentPresentmentError(code: .cancelled, debugDescription: "the provider cancelled the request"))) }
    /// builds the response for the website's raw request and sends it
    public func sendResponse(_ responseHandler: @escaping @Sendable (IdentityDocumentWebPresentmentRawRequest) async throws -> ISO18013MobileDocumentResponse) async throws {
        do {
            let response = try await responseHandler(session.raw)
            session.finish(.success(response))
        } catch {
            session.finish(.failure(error))
            throw error
        }
    }
}

@available(iOS 26.0, *)
@MainActor @resultBuilder public struct IdentityDocumentRequestSceneBuilder {
    public static func buildBlock(_ scene: some IdentityDocumentRequestScene) -> some IdentityDocumentRequestScene { scene }
    public static func buildBlock(_ s0: some IdentityDocumentRequestScene, _ s1: some IdentityDocumentRequestScene) -> some IdentityDocumentRequestScene {
        _IDScenes(scenes: s0._isimMobileDocumentScenes + s1._isimMobileDocumentScenes)
    }
    public static func buildLimitedAvailability(_ scene: some IdentityDocumentRequestScene) -> some IdentityDocumentRequestScene {
        _IDScenes(scenes: scene._isimMobileDocumentScenes)
    }
    public static func buildOptional(_ scene: (some IdentityDocumentRequestScene)?) -> some IdentityDocumentRequestScene {
        _IDScenes(scenes: scene?._isimMobileDocumentScenes ?? [])
    }
}

@available(iOS 26.0, *)
public struct _IDScenes: IdentityDocumentRequestScene {
    let scenes: [_IDMobileDocumentScene]
    public var _isimMobileDocumentScenes: [_IDMobileDocumentScene] { scenes }
}

@available(iOS 26.0, *)
@MainActor @preconcurrency public protocol IdentityDocumentProvider: AppExtension {
    associatedtype Body: IdentityDocumentRequestScene
    @IdentityDocumentRequestSceneBuilder var body: Self.Body { get }
    /// updates the app's registrations to match the documents it holds
    func performRegistrationUpdates() async
}
@available(iOS 26.0, *)
public struct _IDProviderConfiguration: AppExtensionConfiguration {
    nonisolated public func accept(connection: NSXPCConnection) -> Bool { false }
}
@available(iOS 26.0, *)
extension IdentityDocumentProvider {
    public var configuration: _IDProviderConfiguration { _IDProviderConfiguration() }
    /// the extension's entry point: isim's host keeps the provider (it runs in the presenting process)
    public static func main() throws { _IDProviderHost.loaded = Self() }
}

// MARK: - isim: documents, the provider host, the sheets

/// a registered document of an installed provider app
@available(iOS 26.0, *)
struct _IDDocument {
    let registration: MobileDocumentRegistration
    let bundleID: String, appName: String, extensionPath: String
}

@available(iOS 26.0, *)
enum _IDDocuments {
    static let point = "com.apple.identity-document-services.document-provider-ui"
    static var dataDir: String {
        let env = ProcessInfo.processInfo.environment["ISIM_DATA"] ?? ""
        return env.isEmpty ? NSHomeDirectory() + "/.local/share/isim" : env
    }
    /// the provider extension in an app bundle
    static func providerExtension(_ app: String) -> String? {
        let plugins = (app as NSString).appendingPathComponent("PlugIns")
        for n in ((try? FileManager.default.contentsOfDirectory(atPath: plugins)) ?? []).sorted() where n.hasSuffix(".appex") {
            let p = (plugins as NSString).appendingPathComponent(n)
            let info = NSDictionary(contentsOfFile: (p as NSString).appendingPathComponent("Info.plist")) as? [String: Any]
            if (info?["EXAppExtensionAttributes"] as? [String: Any])?["EXExtensionPointIdentifier"] as? String == point { return p }
        }
        return nil
    }
    /// the still valid registrations of the apps (this one and the installed ones) that have a provider extension
    static func registered() -> [_IDDocument] {
        var apps = [Bundle.main.bundlePath]
        let dir = ProcessInfo.processInfo.environment["ISIM_APPS"] ?? (dataDir as NSString).appendingPathComponent("Applications")
        apps += ((try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? []).sorted().filter { $0.hasSuffix(".app") }.map { (dir as NSString).appendingPathComponent($0) }
        var seen = Set<String>(), out: [_IDDocument] = []
        let now = Date()
        for app in apps {
            guard let info = NSDictionary(contentsOfFile: (app as NSString).appendingPathComponent("Info.plist")) as? [String: Any],
                  let id = info["CFBundleIdentifier"] as? String, seen.insert(id).inserted, let ext = providerExtension(app) else { continue }
            let name = info["CFBundleDisplayName"] as? String ?? info["CFBundleName"] as? String ?? id
            let file = dataDir + "/Library/isim/IdentityDocuments/\(id).json"
            guard let d = FileManager.default.contents(atPath: file), let list = (try? JSONSerialization.jsonObject(with: d)) as? [[String: Any]] else { continue }
            for e in list {
                guard let type = e["mobileDocumentType"] as? String, let doc = e["documentIdentifier"] as? String else { continue }
                let until = (e["invalidationDate"] as? Double).map { Date(timeIntervalSince1970: $0) }
                guard (until ?? .distantFuture) > now else { continue }
                let r = MobileDocumentRegistration(mobileDocumentType: type, supportedAuthorityKeyIdentifiers: [], documentIdentifier: doc, invalidationDate: until)
                out.append(_IDDocument(registration: r, bundleID: id, appName: name, extensionPath: ext))
            }
        }
        return out
    }
    static func displayName(_ type: String) -> String {
        switch type {
        case "org.iso.18013.5.1.mDL": return "Driver's License"
        case "org.iso.23220.photoID.1": return "Photo ID"
        case "eu.europa.ec.eudi.pid.1": return "Personal ID"
        default: return type
        }
    }
}

/// the provider extension, loaded into this process
@available(iOS 26.0, *)
@MainActor enum _IDProviderHost {
    static var loaded: (any IdentityDocumentProvider)?
    static var loadedPath: String?
    static func scene(_ path: String) -> _IDMobileDocumentScene? {
        if loadedPath != path {
            loaded = nil
            let info = NSDictionary(contentsOfFile: (path as NSString).appendingPathComponent("Info.plist")) as? [String: Any]
            let exe = (path as NSString).appendingPathComponent(info?["CFBundleExecutable"] as? String ?? ((path as NSString).lastPathComponent as NSString).deletingPathExtension)
            guard let h = dlopen(exe, RTLD_NOW) else { NSLog("isim IdentityDocumentServicesUI: cannot load %@: %s", path, dlerror()); return nil }
            if let reg = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "isim_bundle_register_extension") {
                unsafeBitCast(reg, to: (@convention(c) (NSString) -> Void).self)(path as NSString)
            }
            if let m = dlsym(h, "main") {
                _ = unsafeBitCast(m, to: (@convention(c) (Int32, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Int32).self)(0, nil)
            }
            loadedPath = path
            NSLog("isim IdentityDocumentServicesUI: loaded the provider extension %@", (path as NSString).lastPathComponent)
            if let p = loaded { Task { await p.performRegistrationUpdates() } }
        }
        return loaded?.body._isimMobileDocumentScenes.first
    }
}

/// one presentment: the raw request and how it ended
@available(iOS 26.0, *)
final class _IDSession: @unchecked Sendable {
    let raw: IdentityDocumentWebPresentmentRawRequest
    private var done: ((Result<ISO18013MobileDocumentResponse, Error>) -> Void)?
    init(raw: IdentityDocumentWebPresentmentRawRequest, done: @escaping (Result<ISO18013MobileDocumentResponse, Error>) -> Void) { self.raw = raw; self.done = done }
    func finish(_ r: Result<ISO18013MobileDocumentResponse, Error>) {
        let d = done; done = nil
        DispatchQueue.main.async { d?(r) }
    }
}

@available(iOS 26.0, *)
@MainActor enum _IDSheets {
    static func top(_ anchor: UIWindow?) -> UIViewController? {
        let windows = UIApplication.shared.windows
        var t = (anchor ?? windows.first { $0.isKeyWindow } ?? windows.first)?.rootViewController
        while let p = t?.presentedViewController, !p.isBeingDismissed { t = p }
        return t
    }
    /// the document sheet: the matching documents, or none
    static func choose(_ documents: [_IDDocument], request: ISO18013MobileDocumentRequest, origin: URL, anchor: UIWindow?) async -> _IDDocument? {
        if let answer = ProcessInfo.processInfo.environment["ISIM_IDENTITY_DOCUMENT"] {
            return answer == "cancel" ? nil : documents.first { $0.registration.documentIdentifier == answer }
        }
        guard let top = top(anchor) else { return nil }
        let elements = Set(request.presentmentRequests.flatMap { $0.documentRequestSets.flatMap { $0.requests.flatMap { $0.namespaces.values.flatMap(\.keys) } } })
        let readable = elements.sorted().map { $0.replacingOccurrences(of: "_", with: " ").capitalized }.joined(separator: ", ")
        return await withCheckedContinuation { (c: CheckedContinuation<_IDDocument?, Never>) in
            let host = origin.host ?? origin.absoluteString
            let a = UIAlertController(title: documents.isEmpty ? "No Documents" : "Verify Your Identity",
                                      message: documents.isEmpty ? "No ID in your apps can be used by “\(host)”."
                                          : "“\(host)” wants to see: \(readable).", preferredStyle: .actionSheet)
            for (i, d) in documents.enumerated() {
                let action = UIAlertAction(title: "\(_IDDocuments.displayName(d.registration.mobileDocumentType)) — \(d.appName)", style: .default) { _ in c.resume(returning: d) }
                a.addAction(action)
                _ = i
            }
            a.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in c.resume(returning: nil) })
            a.view.accessibilityIdentifier = "isim-iddoc-sheet"
            top.present(a, animated: true)
            NSLog("isim IdentityDocumentServicesUI: document sheet (%d documents)", documents.count)
        }
    }
    /// the provider's scene in a sheet until it responds or cancels
    static func present(_ scene: _IDMobileDocumentScene, request: ISO18013MobileDocumentRequest, raw: IdentityDocumentWebPresentmentRawRequest,
                        origin: URL, anchor: UIWindow?) async throws -> ISO18013MobileDocumentResponse {
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<ISO18013MobileDocumentResponse, Error>) in
            nonisolated(unsafe) var sheet: UIViewController?
            let session = _IDSession(raw: raw) { result in
                sheet?.dismiss(animated: true)
                c.resume(with: result)
            }
            let context = ISO18013MobileDocumentRequestContext(request: request, requestingWebsiteOrigin: origin, session: session)
            let vc = UIHostingController(rootView: scene.view(context))
            vc.view.accessibilityIdentifier = "isim-iddoc-provider"
            vc.presentationController?.delegate = _IDDismissal.shared
            _IDDismissal.shared.session = session
            sheet = vc
            guard let top = top(anchor) else {
                session.finish(.failure(IdentityDocumentPresentmentError(code: .unknown, debugDescription: "no window for the provider's sheet"))); return
            }
            top.present(vc, animated: true)
        }
    }
}

/// a provider sheet swiped away: cancelled
@available(iOS 26.0, *)
final class _IDDismissal: NSObject, UIAdaptivePresentationControllerDelegate, @unchecked Sendable {
    static let shared = _IDDismissal()
    var session: _IDSession?
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        session?.finish(.failure(IdentityDocumentPresentmentError(code: .cancelled, debugDescription: "the sheet was dismissed")))
        session = nil
    }
}
