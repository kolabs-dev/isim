// HelloMusic, -musickit: MusicKit on isim — authorization, library requests (filtered, sorted; albums, artists,
// playlists), the catalog (search, resources, raw data requests: the Apple Music API with a developer token,
// ISIM_MUSICKIT_*), the subscription, and ApplicationMusicPlayer playing an album from the library. Results are logged.
import UIKit
import MusicKit

private func log(_ s: String) { NSLog("HelloMusicKit: %@", s) }

final class MusicKitViewController: UIViewController {
    let label = UILabel()
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        label.frame = CGRect(x: 20, y: 80, width: 360, height: 40); label.accessibilityIdentifier = "now-playing"
        view.addSubview(label)
    }
    var started = false
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !started else { return }
        started = true
        Task { @MainActor in await self.run() }
    }

    @MainActor func run() async {
        log("status before \(MusicAuthorization.currentStatus)")
        let status = await MusicAuthorization.request()
        log("status \(status)")
        do {
            var all = MusicLibraryRequest<Song>()
            all.sort(by: \.title, ascending: true)
            let songs = try await all.response().items
            log("library songs \(songs.count): \(songs.map(\.title).joined(separator: ", "))")
            var byArtist = MusicLibraryRequest<Song>()
            byArtist.filter(matching: \.artistName, equalTo: "The Oscillators")
            log("by artist \(try await byArtist.response().items.map(\.title).joined(separator: ", "))")
            var search = MusicLibraryRequest<Song>()
            search.filter(matching: \.title, contains: "loop")
            log("contains loop \(try await search.response().items.map(\.title).joined(separator: ", "))")
            let albums = try await MusicLibraryRequest<Album>().response().items
            log("albums \(albums.map { "\($0.title) (\($0.trackCount))" }.joined(separator: ", "))")
            let artists = try await MusicLibraryRequest<Artist>().response().items
            log("artists \(artists.map(\.name).sorted().joined(separator: ", "))")
            let playlists = try await MusicLibraryRequest<Playlist>().response().items
            log("playlists \(playlists.map { "\($0.name) (\($0.tracks?.count ?? 0))" }.joined(separator: ", "))")
            if let s = songs.first { log("song details artwork=\(s.artwork?.url(width: 100, height: 100)?.isFileURL ?? false) duration=\(Int(s.duration ?? 0)) albums=\(s.albums?.count ?? 0)") }

            // the app's player: the first album
            let player = ApplicationMusicPlayer.shared
            if let album = albums.first {
                player.queue = ApplicationMusicPlayer.Queue(for: [album])
                try await player.play()
                log("playing \(player.queue.currentEntry?.title ?? "-") status=\(player.state.playbackStatus) entries=\(player.queue.entries.count)")
                label.text = player.queue.currentEntry?.title
                try await player.skipToNextEntry()
                log("next \(player.queue.currentEntry?.title ?? "-")")
                player.pause()
                log("paused status=\(player.state.playbackStatus)")
            }
        } catch { log("library error \(error)") }

        let sub = try? await MusicSubscription.current
        log("subscription canPlayCatalogContent=\(sub?.canPlayCatalogContent ?? true)")
        do {
            var request = MusicCatalogSearchRequest(term: "sine wave", types: [Song.self, Album.self])
            request.limit = 5
            let r = try await request.response()
            log("catalog songs \(r.songs.map { "\($0.title) by \($0.artistName) \(Int($0.duration ?? 0))s" }.joined(separator: ", ")) albums \(r.albums.map(\.title).joined(separator: ", "))")
            if let first = r.songs.first {
                let byID = try await MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: first.id).response()
                log("resource \(byID.items.first?.title ?? "none") artwork=\(byID.items.first?.artwork?.url(width: 200, height: 200)?.absoluteString ?? "none")")
                let player = ApplicationMusicPlayer.shared
                player.queue = [first]
                do { try await player.play(); log("catalog play started") } catch { log("catalog play error \(error)") }
            }
            let url = URL(string: "https://api.music.apple.com/v1/catalog/us/charts?types=songs")!
            let data = try await MusicDataRequest(urlRequest: URLRequest(url: url)).response()
            log("data request status=\(data.urlResponse.statusCode) bytes=\(data.data.count)")
        } catch { log("catalog error \(error)") }
        log("done")
    }
}
