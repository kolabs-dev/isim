// Sample: the music library on isim — MPMediaLibrary authorization, MPMediaQuery (songs, albums, artists, playlists,
// predicates, sections), MPMusicPlayerController (queue, play, skip, shuffle, repeat, notifications), app playlists and
// MPMediaPickerController. The library is the simulated device's (six generated songs on a new device).
import UIKit
import MediaPlayer

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = MusicViewController()
        window?.makeKeyAndVisible()
        return true
    }
}

func log(_ s: String) { NSLog("HelloMusic: %@", s) }

final class MusicViewController: UIViewController, MPMediaPickerControllerDelegate {
    let player = MPMusicPlayerController.systemMusicPlayer
    let nowPlaying = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let title = UILabel(); title.text = "Music"; title.font = .systemFont(ofSize: 34, weight: .bold)
        title.frame = CGRect(x: 20, y: 64, width: 300, height: 41); view.addSubview(title)
        nowPlaying.frame = CGRect(x: 20, y: 120, width: 360, height: 44); nowPlaying.accessibilityIdentifier = "now-playing"
        nowPlaying.text = "Not Playing"; view.addSubview(nowPlaying)
        for (i, (name, sel)) in [("Pick Songs", #selector(pick)), ("Next", #selector(nextSong))].enumerated() {
            let b = UIButton(type: .system); b.setTitle(name, for: .normal); b.accessibilityIdentifier = name.lowercased().replacingOccurrences(of: " ", with: "-")
            b.frame = CGRect(x: 20 + i * 140, y: 180, width: 130, height: 44)
            b.addTarget(self, action: sel, for: .touchUpInside); view.addSubview(b)
        }
        MPMediaLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                log("authorization \(status == .authorized)")
                if status == .authorized { self.library() }
            }
        }
    }

    func library() {
        let songs = MPMediaQuery.songs().items ?? []
        log("songs \(songs.count): \(songs.map { $0.title ?? "" }.joined(separator: ", "))")
        let albums = MPMediaQuery.albums().collections ?? []
        log("albums \(albums.map { "\($0.representativeItem?.albumTitle ?? "") (\($0.count))" }.joined(separator: ", "))")
        let artists = MPMediaQuery.artists().collections ?? []
        log("artists \(artists.map { $0.representativeItem?.artist ?? "" }.joined(separator: ", "))")
        let q = MPMediaQuery.songs()
        q.addFilterPredicate(MPMediaPropertyPredicate(value: "Ambient", forProperty: MPMediaItemPropertyGenre))
        log("ambient \(q.items?.map { $0.title ?? "" }.joined(separator: ", ") ?? "-")")
        let contains = MPMediaQuery.songs()
        contains.addFilterPredicate(MPMediaPropertyPredicate(value: "sine", forProperty: MPMediaItemPropertyTitle, comparisonType: .contains))
        log("contains sine \(contains.items?.count ?? -1)")
        let first = songs.first!
        let byID = MPMediaQuery(filterPredicates: [MPMediaPropertyPredicate(value: NSNumber(value: first.persistentID), forProperty: MPMediaItemPropertyPersistentID)])
        log("by id \(byID.items?.first?.title ?? "-") duration \(Int(first.playbackDuration)) artwork \(first.artwork?.image(at: CGSize(width: 60, height: 60)) != nil) asset \(first.assetURL?.isFileURL == true)")
        log("sections \(MPMediaQuery.songs().itemSections?.map(\.title).joined() ?? "-")")
        let lists = MPMediaQuery.playlists().collections as? [MPMediaPlaylist] ?? []
        log("playlists \(lists.map { "\($0.name ?? "") (\($0.count))" }.joined(separator: ", "))")
        // an app playlist
        let meta = MPMediaPlaylistCreationMetadata(name: "Demo Mix")
        meta.descriptionText = "Made by HelloMusic"
        MPMediaLibrary.default().getPlaylist(with: UUID(uuidString: "5C1A2D3E-4F50-6172-8394-A5B6C7D8E9F0")!, creationMetadata: meta) { p, _ in
            p?.add(Array(songs.suffix(2))) { _ in
                DispatchQueue.main.async { log("app playlist \(p?.name ?? "-") \(MPMediaQuery.playlists().collections?.count ?? 0)") }
            }
        }
        // play the Electronic album through the system player
        NotificationCenter.default.addObserver(self, selector: #selector(itemChanged), name: .MPMusicPlayerControllerNowPlayingItemDidChange, object: player)
        NotificationCenter.default.addObserver(self, selector: #selector(stateChanged), name: .MPMusicPlayerControllerPlaybackStateDidChange, object: player)
        player.beginGeneratingPlaybackNotifications()
        let album = MPMediaQuery.songs()
        album.addFilterPredicate(MPMediaPropertyPredicate(value: "Sine Waves", forProperty: MPMediaItemPropertyAlbumTitle))
        player.setQueue(with: album)
        player.repeatMode = .all
        player.play()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
            log("playing \(player.nowPlayingItem?.title ?? "-") index \(player.indexOfNowPlayingItem) time \(player.currentPlaybackTime > 0.2)")
        }
    }
    @objc func itemChanged() { nowPlaying.text = player.nowPlayingItem?.title ?? "Not Playing"; log("now playing item \(player.nowPlayingItem?.title ?? "-")") }
    @objc func stateChanged() { log("state \(player.playbackState.rawValue)") }
    @objc func nextSong() { player.skipToNextItem() }
    @objc func pick() {
        let picker = MPMediaPickerController(mediaTypes: .music)
        picker.allowsPickingMultipleItems = true
        picker.delegate = self
        present(picker, animated: true)
    }
    func mediaPicker(_ mediaPicker: MPMediaPickerController, didPickMediaItems mediaItemCollection: MPMediaItemCollection) {
        log("picked \(mediaItemCollection.items.map { $0.title ?? "" }.joined(separator: ", "))")
        player.setQueue(with: mediaItemCollection)
        player.play()
        mediaPicker.dismiss(animated: true)
    }
    func mediaPickerDidCancel(_ mediaPicker: MPMediaPickerController) { mediaPicker.dismiss(animated: true) }
}
