// The sample's identity document provider extension (IdentityDocumentServicesUI, iOS 26; issue #744): when a website asks
// for the mobile driver's license the app registered, its request scene shows what the website wants to see; "Share"
// sends a response for the website's raw request, "Don't Share" cancels.
import SwiftUI
import IdentityDocumentServices
import IdentityDocumentServicesUI

func log(_ s: String) { print("id \(s)"); fflush(stdout) }

@main
struct LicenseProvider: IdentityDocumentProvider {
    var body: some IdentityDocumentRequestScene {
        ISO18013MobileDocumentRequestScene { context in
            ShareView(context: context)
        }
    }
    func performRegistrationUpdates() async {
        log("provider registration updates \(IdentityDocumentProviderRegistrationStore().registrations.count)")
    }
}

struct ShareView: View {
    let context: ISO18013MobileDocumentRequestContext
    var elements: [String] {
        context.request.presentmentRequests.flatMap { $0.documentRequestSets.flatMap { $0.requests.flatMap { $0.namespaces.values.flatMap(\.keys) } } }.sorted()
    }
    var body: some View {
        VStack(spacing: 16) {
            Text("Driver's License").font(.title2.bold())
            Text("\(context.requestingWebsiteOrigin?.host ?? "A website") wants to see:").accessibilityIdentifier("iddoc-origin")
            ForEach(elements, id: \.self) { Text($0.replacingOccurrences(of: "_", with: " ").capitalized) }
            Button("Share") {
                let shared = elements.joined(separator: ",")
                Task {
                    do {
                        try await context.sendResponse { raw in
                            log("provider responding to \(raw.requestData.count) bytes")
                            return ISO18013MobileDocumentResponse(responseData: Data("isim-mdl:\(shared)".utf8))
                        }
                    } catch { log("provider send failed \(error)") }
                }
            }
            .buttonStyle(.borderedProminent).accessibilityIdentifier("iddoc-share")
            Button("Don't Share") { context.cancel() }.accessibilityIdentifier("iddoc-decline")
        }
        .padding()
        .onAppear { log("provider scene for \(context.requestingWebsiteOrigin?.absoluteString ?? "-") elements=\(elements.count)") }
    }
}
