// RecipeThumbnail: HelloQuickLookExtensions' Thumbnail extension (like Xcode's Thumbnail Extension template): a
// .recipe's thumbnail is an orange card with the recipe's title and how many it serves, drawn in UIKit's current context.
import UIKit
import QuickLookThumbnailing

class ThumbnailProvider: QLThumbnailProvider {
    override func provideThumbnail(for request: QLFileThumbnailRequest, _ handler: @escaping (QLThumbnailReply?, (any Error)?) -> Void) {
        let data = (try? Data(contentsOf: request.fileURL)) ?? Data()
        let recipe = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        let title = recipe["title"] as? String ?? "Recipe"
        let serves = recipe["serves"] as? Int ?? 0
        let size = request.maximumSize
        let reply = QLThumbnailReply(contextSize: size, currentContextDrawing: { () -> Bool in
            UIColor.systemOrange.setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 12).fill()
            (title as NSString).draw(at: CGPoint(x: 10, y: 10), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 18), .foregroundColor: UIColor.white])
            ("Serves \(serves)" as NSString).draw(at: CGPoint(x: 10, y: 36), withAttributes: [.font: UIFont.systemFont(ofSize: 13), .foregroundColor: UIColor.white])
            return true
        })
        print("qlx thumbnail provider \(title) \(Int(size.width))x\(Int(size.height)) scale \(request.scale)")
        handler(reply, nil)
    }
}
