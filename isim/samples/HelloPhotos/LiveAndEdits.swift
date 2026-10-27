// HelloPhotos: Live Photos and edits (issue #372). "Save Live Photo" saves a drawn still with a paired movie
// (PHAssetCreationRequest .photo + .pairedVideo), reads it back (photoLive, playback style, resources,
// requestLivePhoto) and shows it in a PHLivePhotoView, which "Play Live Photo" plays. "Edit Photo" edits the first
// library photo through PHContentEditingInput / PHContentEditingOutput with PHAdjustmentData, reads the edit and the
// original back, and reverts it. Every step prints a line the test reads.
import SwiftUI
import PhotosUI

final class LiveViewDelegate: NSObject, PHLivePhotoViewDelegate {
    func livePhotoView(_ livePhotoView: PHLivePhotoView, willBeginPlaybackWith playbackStyle: PHLivePhotoViewPlaybackStyle) {
        print("live will begin \(playbackStyle.rawValue)")
    }
    func livePhotoView(_ livePhotoView: PHLivePhotoView, didEndPlaybackWith playbackStyle: PHLivePhotoViewPlaybackStyle) {
        print("live did end \(playbackStyle.rawValue)")
    }
}

/// PHLivePhotoView in SwiftUI
struct LivePhotoViewer: UIViewRepresentable {
    let livePhoto: PHLivePhoto?
    let view: PHLivePhotoView
    func makeUIView(context: Context) -> PHLivePhotoView { view }
    func updateUIView(_ v: PHLivePhotoView, context: Context) { if v.livePhoto !== livePhoto { v.livePhoto = livePhoto } }
}

extension PhotosModel {
    /// a 160 x 120 still: orange with a white disc
    nonisolated func writeStill() -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("still.jpg")
        let ctx = CGContext(data: nil, width: 160, height: 120, bitsPerComponent: 8, bytesPerRow: 160 * 4, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(red: 1, green: 0.5, blue: 0, alpha: 1); ctx.fill(CGRect(x: 0, y: 0, width: 160, height: 120))
        ctx.setFillColor(red: 1, green: 1, blue: 1, alpha: 1); ctx.fillEllipse(in: CGRect(x: 55, y: 35, width: 50, height: 50))
        let img = UIImage(cgImage: ctx.makeImage()!)
        try? img.jpegData(compressionQuality: 0.9)?.write(to: url)
        return url
    }

    func saveLivePhoto() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { _ in
            do {
                let still = self.writeStill(), movie = try self.writeMovie()
                let supported = PHAssetCreationRequest.supportsAssetResourceTypes([PHAssetResourceType.photo.rawValue, PHAssetResourceType.pairedVideo.rawValue] as [NSNumber])
                var id = ""
                try PHPhotoLibrary.shared().performChangesAndWait {
                    let r = PHAssetCreationRequest.forAsset()
                    r.addResource(with: .photo, fileURL: still, options: nil)
                    r.addResource(with: .pairedVideo, fileURL: movie, options: nil)
                    id = r.placeholderForCreatedAsset?.localIdentifier ?? ""
                }
                guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject else { print("live missing"); return }
                let types = PHAssetResource.assetResources(for: asset).map(\.type.rawValue)
                print("live saved supported \(supported) live \(asset.mediaSubtypes.contains(.photoLive)) style \(asset.playbackStyle.rawValue) resources \(types)")
                PHImageManager.default().requestLivePhoto(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: nil) { live, info in
                    print("live photo \(live.map { "\(Int($0.size.width))x\(Int($0.size.height))" } ?? "nil") degraded \(info?[PHImageResultIsDegradedKey] as? Bool ?? true)")
                    MainActor.assumeIsolated { self.livePhotoView.delegate = self.liveDelegate; self.livePhoto = live }
                }
                PHLivePhoto.request(withResourceFileURLs: [movie, still], placeholderImage: nil, targetSize: .zero, contentMode: .aspectFit) { live, info in
                    print("live from files \(live != nil) degraded \(info[PHLivePhotoInfoIsDegradedKey] as? Bool ?? true)")
                }
            } catch { print("live error \(error)") }
        }
    }

    func playLivePhoto() { livePhotoView.startPlayback(with: .full) }

    func editPhoto() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { _ in
            guard let asset = PHAsset.fetchAssets(with: .image, options: nil).firstObject else { print("edit: no photo"); return }
            let opts = PHContentEditingInputRequestOptions()
            opts.canHandleAdjustmentData = { $0.formatIdentifier == "dev.isim.hellophotos" }
            asset.requestContentEditingInput(with: opts) { input, _ in
                guard let input, let url = input.fullSizeImageURL, let img = UIImage(contentsOfFile: url.path) else { print("edit: no input"); return }
                print("edit input \(input.mediaType == .image) adjustments \(input.adjustmentData == nil ? "none" : "some") type \(input.uniformTypeIdentifier ?? "-")")
                // the edit: the picture under a translucent blue wash
                let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1
                let edited = UIGraphicsImageRenderer(size: img.size, format: fmt).image { ctx in
                    img.draw(at: .zero)
                    UIColor(red: 0, green: 0, blue: 1, alpha: 0.5).setFill(); ctx.fill(CGRect(origin: .zero, size: img.size))
                }
                let output = PHContentEditingOutput(contentEditingInput: input)
                output.adjustmentData = PHAdjustmentData(formatIdentifier: "dev.isim.hellophotos", formatVersion: "1.0", data: Data("blue wash 0.5".utf8))
                try? edited.jpegData(compressionQuality: 0.9)?.write(to: output.renderedContentURL)
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest(for: asset).contentEditingOutput = output
                }) { ok, error in
                    let after = PHAsset.fetchAssets(withLocalIdentifiers: [asset.localIdentifier], options: nil).firstObject!
                    let types = PHAssetResource.assetResources(for: after).map(\.type.rawValue)
                    print("edit saved \(ok) adjusted \(after.hasAdjustments) resources \(types)")
                    let current = PHImageRequestOptions(); current.isSynchronous = true
                    let original = PHImageRequestOptions(); original.isSynchronous = true; original.version = .original
                    func blue(_ o: PHImageRequestOptions) -> Int {
                        var b = -1
                        PHImageManager.default().requestImage(for: after, targetSize: CGSize(width: 40, height: 40), contentMode: .aspectFit, options: o) { im, _ in
                            guard let cg = im?.cgImage, let data = cg.dataProvider?.data, let p = CFDataGetBytePtr(data) else { return }
                            let off = (cg.height / 2) * cg.bytesPerRow + (cg.width / 2) * (cg.bitsPerPixel / 8)
                            b = Int(p[off + 2])   // RGBA
                        }
                        return b
                    }
                    let (bc, bo) = (blue(current), blue(original))
                    print("edit current bluer \(bc > bo + 40)")
                    after.requestContentEditingInput(with: opts) { again, _ in
                        let text = again?.adjustmentData.map { String(decoding: $0.data, as: UTF8.self) } ?? "-"
                        let fromOriginal = again?.fullSizeImageURL?.lastPathComponent.contains("_E") == false
                        print("edit again adjustments \(text) original \(fromOriginal)")
                        PHPhotoLibrary.shared().performChanges({
                            PHAssetChangeRequest(for: after).revertAssetContentToOriginal()
                        }) { ok, _ in
                            let reverted = PHAsset.fetchAssets(withLocalIdentifiers: [asset.localIdentifier], options: nil).firstObject!
                            print("edit reverted \(ok) adjusted \(reverted.hasAdjustments) resources \(PHAssetResource.assetResources(for: reverted).count)")
                        }
                    }
                }
            }
        }
    }
}

struct LiveAndEditsSection: View {
    @ObservedObject var model: PhotosModel
    var body: some View {
        Section("Live Photos & Edits") {
            Button("Save Live Photo") { model.saveLivePhoto() }.accessibilityIdentifier("saveLive")
            if model.livePhoto != nil {
                LivePhotoViewer(livePhoto: model.livePhoto, view: model.livePhotoView)
                    .frame(height: 120).accessibilityIdentifier("livePhotoView")
                Button("Play Live Photo") { model.playLivePhoto() }.accessibilityIdentifier("playLive")
                Image(uiImage: PHLivePhotoView.livePhotoBadgeImage(options: [])).accessibilityIdentifier("liveBadge")
            }
            Button("Edit Photo") { model.editPhoto() }.accessibilityIdentifier("editPhoto")
        }
    }
}
