// Sample: an identity document provider on isim (IdentityDocumentServices, iOS 26; issue #403). It registers the mobile
// driver's license it holds (its entitlement lists org.iso.18013.5.1.mDL), is refused a document type it is not
// entitled to, lists and removes registrations, and validates a website's ISO 18013-5 DeviceRequest (bundled as
// request.cbor). Every step is printed ("id ...").
import UIKit
import IdentityDocumentServices

func log(_ s: String) { print("id \(s)"); fflush(stdout) }

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        let vc = UIViewController()
        vc.view.backgroundColor = .systemBackground
        window?.rootViewController = vc
        window?.makeKeyAndVisible()
        if #available(iOS 26.0, *) { Task { await run() } } else { log("needs iOS 26") }
        return true
    }

    @available(iOS 26.0, *)
    func run() async {
        let store = IdentityDocumentProviderRegistrationStore()
        log("status \(store.status)")
        let license = MobileDocumentRegistration(mobileDocumentType: "org.iso.18013.5.1.mDL", supportedAuthorityKeyIdentifiers: [Data([1, 2, 3])],
                                                 documentIdentifier: "license-1", invalidationDate: Date(timeIntervalSinceNow: 86400 * 365))
        do { try await store.addRegistration(license); log("added license-1") } catch { log("add failed \(error)") }
        let expired = MobileDocumentRegistration(mobileDocumentType: "org.iso.18013.5.1.mDL", supportedAuthorityKeyIdentifiers: [],
                                                 documentIdentifier: "old", invalidationDate: Date(timeIntervalSinceNow: -60))
        do { try await store.addRegistration(expired); log("added old") } catch { log("add old failed \(error)") }
        let photoID = MobileDocumentRegistration(mobileDocumentType: "org.iso.23220.photoID.1", supportedAuthorityKeyIdentifiers: [],
                                                 documentIdentifier: "photo-1", invalidationDate: nil)
        do { try await store.addRegistration(photoID); log("added photo-1") } catch { log("photo id refused \(error)") }
        let regs = store.registrations.compactMap { $0 as? MobileDocumentRegistration }
        log("registrations \(regs.map { "\($0.documentIdentifier):\($0.mobileDocumentType)" })")
        do { try await store.removeRegistration(forDocumentIdentifier: "nope") } catch { log("remove missing \(error)") }

        guard let url = Bundle.main.url(forResource: "request", withExtension: "cbor"), let data = try? Data(contentsOf: url) else { log("no request"); return }
        let validator = IdentityDocumentWebPresentmentRawRequestValidator()
        do {
            let request = try validator.validateISO18013MobileDocumentRequest(data, origin: URL(string: "https://verifier.isim.dev")!)
            for p in request.presentmentRequests {
                for set in p.documentRequestSets {
                    for r in set.requests {
                        let elements = r.namespaces.flatMap { ns, e in e.map { "\(ns).\($0.key)=\($0.value.isRetaining)" } }.sorted()
                        log("request \(r.documentType) mandatory=\(p.isMandatory) \(elements)")
                    }
                }
            }
            log("reader chain \(request.requestAuthentications.map { $0.authenticationCertificateChain.count })")
        } catch { log("validate failed \(error)") }
        do { _ = try validator.validateISO18013MobileDocumentRequest(data, origin: URL(string: "http://verifier.isim.dev")!) }
        catch let e as IdentityDocumentPresentmentError { log("http origin \(e.code)") } catch { log("http origin other \(error)") }
        do { _ = try validator.validateISO18013MobileDocumentRequest(Data([0xA1, 0x01]), origin: URL(string: "https://verifier.isim.dev")!) }
        catch { log("garbage \((error as? IdentityDocumentPresentmentError)?.code == .invalidRequest)") }
    }
}
