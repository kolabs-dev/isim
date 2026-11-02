// isim Social Swift overlay (self-authored): SLRequest's URL-loading methods with Swift's Foundation types. The Objective-C
// header hides them from Swift (NSURLRequest and NSHTTPURLResponse are Foundation's overlay classes, which Swift sees as
// URLRequest and HTTPURLResponse); preparedURLRequest() asks the Objective-C class (frameworks/Social/Social.m) for the
// request, and perform(handler:) sends it with URLSession, without an account, as the Objective-C method does.
@_exported import Social
import Foundation

public typealias SLRequestHandler = (Data?, HTTPURLResponse?, Error?) -> Void

extension SLRequest {
    /// the request with the parameters and multipart data in it (no account signs it on isim)
    public func preparedURLRequest() -> URLRequest! {
        let sel = NSSelectorFromString("preparedURLRequest")
        typealias Fn = @convention(c) (AnyObject, Selector) -> Unmanaged<AnyObject>?
        let f = unsafeBitCast(method(for: sel), to: Fn.self)
        return (f(self, sel)?.takeUnretainedValue() as? NSURLRequest).map { $0 as URLRequest }
    }

    /// sends the request; the handler runs on an arbitrary queue, as on iOS
    public func perform(handler: SLRequestHandler!) {
        guard let request = preparedURLRequest() else { handler?(nil, nil, URLError(.badURL)); return }
        NSLog("isim: SLRequest %@ %@ sent without an account", request.httpMethod ?? "GET", request.url?.absoluteString ?? "-")
        URLSession.shared.dataTask(with: request) { data, response, error in
            handler?(data, response as? HTTPURLResponse, error)
        }.resume()
    }
}
