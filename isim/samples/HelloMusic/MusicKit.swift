// HelloMusic, -musickit: MusicKit on isim — authorization, library requests (filtered, sorted; albums, artists,
// playlists) and library search, the catalog (search, resources, charts, relationships with with(_:), music videos,
// stations, record labels, raw data requests: the Apple Music API with a developer token, ISIM_MUSICKIT_*), recently
// played items and recommendations (the user token), the subscription and its offer sheet, ArtworkImage, and
// ApplicationMusicPlayer playing an album from the library. Results are logged.
import UIKit
import SwiftUI
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
            await catalogDepth()
        } catch { log("catalog error \(error)") }
        await userRequests()
        await librarySearch()
        showOffer()
    }

    /// charts, relationships, music videos, stations and record labels
    func catalogDepth() async {
        do {
            var charts = MusicCatalogChartsRequest(kinds: [.mostPlayed], types: [Song.self, MusicVideo.self])
            charts.limit = 10
            let c = try await charts.response()
            log("charts songs \(c.songCharts.map { "\($0.title) [\($0.kind)] \($0.items.map(\.title).joined(separator: "/"))" }.joined(separator: "; ")) videos \(c.musicVideoCharts.first?.items.first?.title ?? "none")")
            if let song = c.songCharts.first?.items.first {
                let full = try await song.with([.albums, .genres, .musicVideos])
                log("with albums=\(full.albums?.map(\.title).joined(separator: "/") ?? "-") genres=\(full.genres?.map { "\($0.name)<\($0.parent?.name ?? "")" }.joined(separator: "/") ?? "-") videos=\(full.musicVideos?.count ?? 0)")
            }
            var search = MusicCatalogSearchRequest(term: "signals", types: [MusicVideo.self, Station.self, RecordLabel.self])
            search.limit = 3
            let r = try await search.response()
            if let v = r.musicVideos.first { log("music video \(v.title) 4K=\(v.has4K ?? false) rating=\(v.contentRating.map { "\($0)" } ?? "-") previews=\(v.previewAssets?.count ?? 0)") }
            if let st = r.stations.first { log("station \(st.name) live=\(st.isLive) provider=\(st.stationProviderName ?? "-")") }
            if let label = r.recordLabels.first {
                let full = try await label.with([.latestReleases])
                log("record label \(full.name) latest=\(full.latestReleases?.map(\.title).joined(separator: "/") ?? "-")")
            }
            let genre = try await MusicCatalogResourceRequest<Genre>(matching: \.id, equalTo: MusicItemID("7")).response()
            log("genre \(genre.items.first?.name ?? "none")")
        } catch { log("catalog depth error \(error)") }
    }

    /// requests about the user: they need the music user token
    func userRequests() async {
        do {
            var recent = MusicRecentlyPlayedRequest<Song>()
            recent.limit = 5
            log("recently played songs \(try await recent.response().items.map(\.title).joined(separator: ", "))")
            let containers = try await MusicRecentlyPlayedContainerRequest().response()
            log("recently played containers \(containers.items.map { "\($0.title)" }.joined(separator: ", "))")
            let recs = try await MusicPersonalRecommendationsRequest().response()
            log("recommendations \(recs.recommendations.map { "\($0.title ?? "-"): \($0.items.map(\.title).joined(separator: "/"))" }.joined(separator: "; "))")
        } catch { log("user error \(error)") }
    }

    func librarySearch() async {
        do {
            var request = MusicLibrarySearchRequest(term: "loop", types: [Song.self, Album.self, Artist.self])
            request.includeTopResults = true
            let r = try await request.response()
            log("library search songs \(r.songs.map(\.title).joined(separator: ", ")) top \(r.topResults.first?.title ?? "none")")
        } catch { log("library search error \(error)") }
    }

    /// ArtworkImage of the first library song, and the subscription offer (isim's sheet)
    @MainActor func showOffer() {
        Task { @MainActor in
            let songs = (try? await MusicLibraryRequest<Song>().response().items) ?? []
            let host = UIHostingController(rootView: OfferView(artwork: songs.first?.artwork))
            host.view.frame = CGRect(x: 0, y: 140, width: view.bounds.width, height: 300)
            addChild(host); view.addSubview(host.view); host.didMove(toParent: self)
        }
    }
}

struct OfferView: View {
    let artwork: Artwork?
    @State var offering = true
    var body: some View {
        VStack {
            if let artwork { ArtworkImage(artwork, width: 120) }
            Text("Library artwork").font(.caption)
        }
        .musicSubscriptionOffer(isPresented: $offering, options: MusicSubscriptionOffer.Options(messageIdentifier: .playMusic)) { error in
            NSLog("HelloMusicKit: %@", "offer loaded error=\(error.map { "\($0)" } ?? "none")")
            NSLog("HelloMusicKit: %@", "done")
        }
    }
}
