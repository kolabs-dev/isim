// HelloCarPlay: a CarPlay audio app (issue #410). On the phone it shows its library; on the CarPlay screen (the script
// command `carplay connect`) a tab bar of a list (playlists, a station row of images) and a grid (genres), the Now
// Playing template with the app's buttons (MPNowPlayingInfoCenter, MPRemoteCommandCenter), an alert and an action
// sheet. It logs what CarPlay does ("cpa ...").
import CarPlay
import MediaPlayer
import UIKit

func log(_ s: String) { NSLog("cpa %@", s) }

func art(_ color: UIColor, _ symbol: String) -> UIImage {
    UIGraphicsImageRenderer(size: CGSize(width: 88, height: 88)).image { ctx in
        color.setFill(); UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 88, height: 88), cornerRadius: 14).fill()
        let s = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 36, weight: .semibold))?.withTintColor(.white, renderingMode: .alwaysOriginal)
        s?.draw(in: CGRect(x: 24, y: 24, width: 40, height: 40))
    }
}

struct Playlist { let name: String; let detail: String; let color: UIColor; let songs: [String] }
let playlists = [
    Playlist(name: "Morning Mix", detail: "12 songs", color: .systemOrange, songs: ["Sunrise", "Coffee Run", "Open Road"]),
    Playlist(name: "Road Trip", detail: "24 songs", color: .systemBlue, songs: ["Highway", "Mile Marker", "Rest Stop"]),
    Playlist(name: "Focus", detail: "8 songs", color: .systemPurple, songs: ["Deep Work", "Quiet Hours"]),
]

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let c = MPRemoteCommandCenter.shared()
        _ = c.playCommand.addTarget { _ in Player.shared.set(playing: true); log("remote play"); return .success }
        _ = c.pauseCommand.addTarget { _ in Player.shared.set(playing: false); log("remote pause"); return .success }
        _ = c.nextTrackCommand.addTarget { _ in Player.shared.skip(1); log("remote next"); return .success }
        _ = c.previousTrackCommand.addTarget { _ in Player.shared.skip(-1); log("remote previous"); return .success }
        log("launched")
        return true
    }
    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        session.role == .carTemplateApplication
            ? UISceneConfiguration(name: "CarPlay", sessionRole: session.role)
            : UISceneConfiguration(name: "Phone", sessionRole: session.role)
    }
}

/// what plays: MPNowPlayingInfoCenter's info, which CarPlay's Now Playing screen shows
final class Player {
    static let shared = Player()
    var playlist = playlists[0], index = 0, playing = false
    func play(_ p: Playlist) { playlist = p; index = 0; set(playing: true) }
    func skip(_ d: Int) { index = (index + d + playlist.songs.count) % playlist.songs.count; publish() }
    func set(playing: Bool) { self.playing = playing; publish() }
    func publish() {
        let c = MPNowPlayingInfoCenter.default()
        c.nowPlayingInfo = [MPMediaItemPropertyTitle: playlist.songs[index], MPMediaItemPropertyArtist: "The isim Band",
                            MPMediaItemPropertyAlbumTitle: playlist.name, MPMediaItemPropertyPlaybackDuration: 214.0,
                            MPNowPlayingInfoPropertyElapsedPlaybackTime: 63.0,
                            MPMediaItemPropertyArtwork: MPMediaItemArtwork(boundsSize: CGSize(width: 88, height: 88)) { _ in art(self.playlist.color, "music.note") }]
        c.playbackState = playing ? .playing : .paused
    }
}

final class PhoneSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let ws = scene as? UIWindowScene else { return }
        let w = UIWindow(windowScene: ws)
        let vc = UIViewController()
        vc.view.backgroundColor = .systemBackground
        let l = UILabel(frame: CGRect(x: 20, y: 120, width: 340, height: 80))
        l.text = "Connect CarPlay to browse your library in the car."
        l.numberOfLines = 0
        vc.view.addSubview(l)
        w.rootViewController = vc
        w.makeKeyAndVisible()
        window = w
    }
}

final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate, CPNowPlayingTemplateObserver, CPInterfaceControllerDelegate {
    var interfaceController: CPInterfaceController?

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didConnect interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        interfaceController.delegate = self
        let library = libraryTemplate()
        library.tabTitle = "Library"
        library.tabImage = UIImage(systemName: "music.note.list")
        let browse = CPGridTemplate(title: "Browse", gridButtons: [("Rock", UIColor.systemRed, "bolt"), ("Jazz", .systemTeal, "music.note"),
                                                                   ("Podcasts", .systemPurple, "mic.fill"), ("Radio", .systemPink, "antenna.radiowaves.left.and.right")].map { g in
            CPGridButton(titleVariants: [g.0], image: art(g.1, g.2)) { [weak self] _ in self?.genre(g.0, g.1) }
        })
        browse.tabSystemItem = .featured
        let tabs = CPTabBarTemplate(templates: [library, browse])
        interfaceController.setRootTemplate(tabs, animated: true) { ok, _ in log("root \(ok)") }
        CPNowPlayingTemplate.shared.add(self)
        CPNowPlayingTemplate.shared.isUpNextButtonEnabled = true
        CPNowPlayingTemplate.shared.updateNowPlayingButtons([
            CPNowPlayingShuffleButton { b in b.isSelected.toggle(); log("shuffle \(b.isSelected)") },
            CPNowPlayingRepeatButton { _ in log("repeat") },
            CPNowPlayingPlaybackRateButton { _ in log("rate") },
        ])
        log("connected \(templateApplicationScene.contentStyle == .dark ? "dark" : "light") tabs=\(tabs.templates.count)")
    }
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        self.interfaceController = nil
        log("disconnected")
    }
    func templateDidAppear(_ aTemplate: CPTemplate, animated: Bool) { log("appeared \(type(of: aTemplate))") }

    func libraryTemplate() -> CPListTemplate {
        let items = playlists.map { p -> CPListItem in
            let i = CPListItem(text: p.name, detailText: p.detail, image: art(p.color, "music.note"), accessoryImage: nil, accessoryType: .disclosureIndicator)
            i.handler = { [weak self] _, done in
                log("selected \(p.name)")
                Player.shared.play(p)
                self?.interfaceController?.pushTemplate(CPNowPlayingTemplate.shared, animated: true) { ok, _ in log("now playing \(ok)") }
                done()
            }
            return i
        }
        let stations = CPListImageRowItem(text: "Stations", images: [art(.systemGreen, "car.fill"), art(.systemIndigo, "moon.fill"), art(.systemYellow, "sun.max.fill")],
                                          imageTitles: ["Drive", "Night", "Day"])
        stations.listImageRowHandler = { _, index, done in log("station \(index)"); done() }
        let t = CPListTemplate(title: "Library", sections: [CPListSection(items: items, header: "Playlists", sectionIndexTitle: nil),
                                                            CPListSection(items: [stations], header: "Radio", sectionIndexTitle: nil)])
        t.trailingNavigationBarButtons = [CPBarButton(title: "Sort") { [weak self] _ in self?.sortSheet() }]
        t.leadingNavigationBarButtons = [CPBarButton(title: "Sign Out") { [weak self] _ in self?.signOutAlert() }]
        return t
    }
    func genre(_ name: String, _ color: UIColor) {
        log("genre \(name)")
        let items = (1...3).map { n in CPListItem(text: "\(name) Hits \(n)", detailText: "Playlist", image: art(color, "music.note")) }
        interfaceController?.pushTemplate(CPListTemplate(title: name, sections: [CPListSection(items: items)]), animated: true, completion: nil)
    }
    func signOutAlert() {
        let a = CPAlertTemplate(titleVariants: ["Sign out of HelloCarPlay?"], actions: [
            CPAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in log("alert cancel"); self?.interfaceController?.dismissTemplate(animated: true, completion: nil) },
            CPAlertAction(title: "Sign Out", style: .destructive) { [weak self] _ in log("alert sign out"); self?.interfaceController?.dismissTemplate(animated: true, completion: nil) },
        ])
        interfaceController?.presentTemplate(a, animated: true) { ok, _ in log("alert \(ok)") }
    }
    func sortSheet() {
        let s = CPActionSheetTemplate(title: "Sort Playlists", message: "Choose an order", actions: ["Name", "Recently Played"].map { o in
            CPAlertAction(title: o, style: .default) { [weak self] _ in log("sort \(o)"); self?.interfaceController?.dismissTemplate(animated: true, completion: nil) }
        } + [CPAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in self?.interfaceController?.dismissTemplate(animated: true, completion: nil) }])
        interfaceController?.presentTemplate(s, animated: true, completion: nil)
    }
    func nowPlayingTemplateUpNextButtonTapped(_ nowPlayingTemplate: CPNowPlayingTemplate) { log("up next") }
}
