# MediaPlayer

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 83.2% of Apple's iOS API (454 of 546, exact) · **Rows:** 11: 7 ✅ 1 🟡 3 ❌ · **iOS:** 2.0+
<!-- /generated:header -->

**Area:** [Media](../COVERAGE.md#media) · **Apple:** [MediaPlayer](https://developer.apple.com/documentation/mediaplayer) · **Issues:** [`area:media`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Amedia)

## How isim implements it

- **Adapted:** a simulated music library (`$ISIM_DATA/Media/Music`).
- Now Playing shows in isim's Control Center and on the lock screen; the `remote` script command sends remote commands.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| MediaPlayer `MPNowPlayingInfoCenter` | ✅ | ≤17 | the info (title, artist, album, artwork, duration, elapsed time, rate) shows in Control Center's Now Playing module and on the lock screen of a booted device; tested (HelloAudio, HelloMusic: Control Center) |
| MediaPlayer `MPRemoteCommandCenter` | ✅ | ≤17 | handlers and selector targets; commands come from the Now Playing controls (Control Center, lock screen) and the `remote NAME [ARG]` script command (tested: play, skip, seek, disabled command, Control Center next) |
| `MPVolumeView` | ✅ | ≤17 | adapted: the device volume (`$ISIM_DATA` setting, isim's mixer master gain; script `volume up\|down\|V`; `outputVolume` KVO) and the route button (AirPlay card); tested (HelloAudio) |
| Music library (`MPMediaLibrary`, `MPMediaQuery`, `MPMusicPlayerController`, `MPMediaPickerController`), MusicKit | 🟡 | ≤17 | adapted: isim's simulated library (six generated songs, a playlist, and audio files added to `$ISIM_DATA/Media/Music`); permission alert; queries, predicates, groupings, sections; system / application / queue players (Now Playing, remote commands), playlists the app creates; the picker sheet; MusicKit: library requests, ApplicationMusicPlayer / SystemMusicPlayer; catalog requests passthrough to the Apple Music API with your developer token (`ISIM_MUSICKIT_DEVELOPER_TOKEN`; tested against a local stand-in); no Apple Music subscription (catalog songs do not play); tested (HelloMusic, HelloMusic -musickit) |
| Remote command types: `MPChangeRepeatModeCommand` (`currentRepeatType`) / `MPChangeRepeatModeCommandEvent`, `MPChangeShuffleModeCommand` (`currentShuffleType`) / `MPChangeShuffleModeCommandEvent`, `MPRepeatType`, `MPShuffleType`, `MPRatingCommand` (`ratingCommand`, `minimumRating`, `maximumRating`) / `MPRatingCommandEvent`, `enableLanguageOptionCommand` / `disableLanguageOptionCommand` with `MPChangeLanguageOptionCommandEvent` | ✅ | ≤17 | adapted: sent with the `remote` script command (`repeat off\|one\|all`, `shuffle off\|items\|collections`, `rating N` clamped to the command's range, `language ID` / `nolanguage ID` naming an option of the Now Playing info); Control Center has no buttons for them, as on iOS; tested (HelloAudio, test_audio) |
| `MPNowPlayingInfoLanguageOption`, `MPNowPlayingInfoLanguageOptionGroup`, `MPNowPlayingInfoPropertyAvailableLanguageOptions` / `CurrentLanguageOptions`, the `MPLanguageOptionCharacteristic…` constants | ✅ | ≤17 | stored in the Now Playing info; the language commands find the option the app offered by identifier or display name; tested (HelloAudio) |
| `MPNowPlayingInfoPropertyPlaybackProgress`, chapter number / count, collection and external identifiers, `ExcludeFromSuggestions` | ✅ | ≤17 | progress (0…1 of the duration) moves Control Center's progress bar when the info has no elapsed time; the others are stored; tested (HelloAudio) |
| `MPNowPlayingSession` (iOS 16: `init(players:)`, `nowPlayingInfoCenter`, `remoteCommandCenter`, `automaticallyPublishesNowPlayingInfo`, `becomeActiveIfPossible`, `isActive`, `canBecomeActive`, `addPlayer` / `removePlayer`, delegate) | ✅ | ≤17 | adapted: the active session's info is what Control Center shows and its command center gets the remote commands; automatic publishing follows the first player's item (duration, elapsed time, rate); tested (HelloAudio -session, test_audio_now_playing_session) |
| Types not yet in isim (iOS 17 and earlier) | ❌ | ≤17 | not implemented, found by the 2026-10 sweep: `MPContentItem`, `MPMediaPlayback`, `MPSystemMusicPlayerController` (3 types; with their members under "Not yet in isim") |
| Types not yet in isim (iOS 26) | ❌ | 26.0 | not implemented, found by the 2026-10 sweep: `MPMediaItemAnimatedArtwork` (1 type; with its members under "Not yet in isim") |
| Types not yet in isim (iOS 27) | ❌ | 27.0 | not implemented, found by the 2026-10 sweep: `MPAppEntityIdentifier` (1 type; with its members under "Not yet in isim") |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
92 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`MPAdTimeRange`](https://developer.apple.com/documentation/mediaplayer/mpadtimerange)
- [`init(CMTimeRange)`](https://developer.apple.com/documentation/mediaplayer/mpadtimerange/init(_:))
- [`init(timeRange: CMTimeRange)`](https://developer.apple.com/documentation/mediaplayer/mpadtimerange/init(timerange:))
- [`var timeRange: CMTimeRange`](https://developer.apple.com/documentation/mediaplayer/mpadtimerange/timerange)
- [`MPAppEntityIdentifier`](https://developer.apple.com/documentation/mediaplayer/mpappentityidentifier)
- [`var description: String`](https://developer.apple.com/documentation/mediaplayer/mpappentityidentifier/description)
- [`var hash: Int`](https://developer.apple.com/documentation/mediaplayer/mpappentityidentifier/hash)
- [`convenience init?(entityIdentifier: EntityIdentifier)`](https://developer.apple.com/documentation/mediaplayer/mpappentityidentifier/init(entityidentifier:))
- [`func isEqual(Any?) -> Bool`](https://developer.apple.com/documentation/mediaplayer/mpappentityidentifier/isequal(_:))
- [`MPContentItem`](https://developer.apple.com/documentation/mediaplayer/mpcontentitem)
- [`var artwork: MPMediaItemArtwork?`](https://developer.apple.com/documentation/mediaplayer/mpcontentitem/artwork)
- [`var identifier: String`](https://developer.apple.com/documentation/mediaplayer/mpcontentitem/identifier)
- [`init(identifier: String)`](https://developer.apple.com/documentation/mediaplayer/mpcontentitem/init(identifier:))
- [`var isContainer: Bool`](https://developer.apple.com/documentation/mediaplayer/mpcontentitem/iscontainer)
- [`var isExplicitContent: Bool`](https://developer.apple.com/documentation/mediaplayer/mpcontentitem/isexplicitcontent)
- [`var isPlayable: Bool`](https://developer.apple.com/documentation/mediaplayer/mpcontentitem/isplayable)
- [`var isStreamingContent: Bool`](https://developer.apple.com/documentation/mediaplayer/mpcontentitem/isstreamingcontent)
- [`var playbackProgress: Float`](https://developer.apple.com/documentation/mediaplayer/mpcontentitem/playbackprogress)
- [`var subtitle: String?`](https://developer.apple.com/documentation/mediaplayer/mpcontentitem/subtitle)
- [`var title: String?`](https://developer.apple.com/documentation/mediaplayer/mpcontentitem/title)
- [`static var cancelled: MPError.Code`](https://developer.apple.com/documentation/mediaplayer/mperror/cancelled)
- [`static var cloudServiceCapabilityMissing: MPError.Code`](https://developer.apple.com/documentation/mediaplayer/mperror/cloudservicecapabilitymissing)
- [`static var networkConnectionFailed: MPError.Code`](https://developer.apple.com/documentation/mediaplayer/mperror/networkconnectionfailed)
- [`static var notFound: MPError.Code`](https://developer.apple.com/documentation/mediaplayer/mperror/notfound)
- [`static var notSupported: MPError.Code`](https://developer.apple.com/documentation/mediaplayer/mperror/notsupported)
- [`static var permissionDenied: MPError.Code`](https://developer.apple.com/documentation/mediaplayer/mperror/permissiondenied)
- [`static var requestTimedOut: MPError.Code`](https://developer.apple.com/documentation/mediaplayer/mperror/requesttimedout)
- [`static var unknown: MPError.Code`](https://developer.apple.com/documentation/mediaplayer/mperror/unknown)
- [`let MPErrorDomain: String`](https://developer.apple.com/documentation/mediaplayer/mperrordomain)
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/mediaplayer/mpmediaentity/init(coder:))
- [`let MPMediaEntityPropertyPersistentID: String`](https://developer.apple.com/documentation/mediaplayer/mpmediaentitypropertypersistentid)
- [`class func persistentIDProperty(forGroupingType: MPMediaGrouping) -> String`](https://developer.apple.com/documentation/mediaplayer/mpmediaitem/persistentidproperty(forgroupingtype:))
- [`var podcastPersistentID: MPMediaEntityPersistentID`](https://developer.apple.com/documentation/mediaplayer/mpmediaitem/podcastpersistentid)
- [`class func titleProperty(forGroupingType: MPMediaGrouping) -> String`](https://developer.apple.com/documentation/mediaplayer/mpmediaitem/titleproperty(forgroupingtype:))
- [`MPMediaItemAnimatedArtwork`](https://developer.apple.com/documentation/mediaplayer/mpmediaitemanimatedartwork)
- [`convenience init(artworkID: String, previewImageRequestHandler: (CGSize) async -> UIImage?, videoAssetFileURLRequestHandler: (CGSize) async -> URL?)`](https://developer.apple.com/documentation/mediaplayer/mpmediaitemanimatedartwork/init(artworkid:previewimagerequesthandler:videoassetfileurlrequesthandler:)-7bb3j)
- [`init(artworkID: String, previewImageRequestHandler: (CGSize, (UIImage?) -> Void) -> Void, videoAssetFileURLRequestHandler: (CGSize, (URL?) -> Void) -> Void)`](https://developer.apple.com/documentation/mediaplayer/mpmediaitemanimatedartwork/init(artworkid:previewimagerequesthandler:videoassetfileurlrequesthandler:)-ieue)
- [`let MPMediaItemPropertyBeatsPerMinute: String`](https://developer.apple.com/documentation/mediaplayer/mpmediaitempropertybeatsperminute)
- [`let MPMediaItemPropertyBookmarkTime: String`](https://developer.apple.com/documentation/mediaplayer/mpmediaitempropertybookmarktime)
- [`let MPMediaItemPropertyComments: String`](https://developer.apple.com/documentation/mediaplayer/mpmediaitempropertycomments)
- [`let MPMediaItemPropertyDiscCount: String`](https://developer.apple.com/documentation/mediaplayer/mpmediaitempropertydisccount)
- [`let MPMediaItemPropertyIsPreorder: String`](https://developer.apple.com/documentation/mediaplayer/mpmediaitempropertyispreorder)
- [`let MPMediaItemPropertyLyrics: String`](https://developer.apple.com/documentation/mediaplayer/mpmediaitempropertylyrics)
- [`let MPMediaItemPropertyPodcastPersistentID: String`](https://developer.apple.com/documentation/mediaplayer/mpmediaitempropertypodcastpersistentid)
- [`let MPMediaItemPropertyPodcastTitle: String`](https://developer.apple.com/documentation/mediaplayer/mpmediaitempropertypodcasttitle)
- [`let MPMediaItemPropertySkipCount: String`](https://developer.apple.com/documentation/mediaplayer/mpmediaitempropertyskipcount)
- [`let MPMediaItemPropertyUserGrouping: String`](https://developer.apple.com/documentation/mediaplayer/mpmediaitempropertyusergrouping)
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/mediaplayer/mpmedialibrary/init(coder:))
- [`MPMediaPlayback`](https://developer.apple.com/documentation/mediaplayer/mpmediaplayback)
- [`func beginSeekingBackward()`](https://developer.apple.com/documentation/mediaplayer/mpmediaplayback/beginseekingbackward())
- [`func beginSeekingForward()`](https://developer.apple.com/documentation/mediaplayer/mpmediaplayback/beginseekingforward())
- [`var currentPlaybackRate: Float`](https://developer.apple.com/documentation/mediaplayer/mpmediaplayback/currentplaybackrate)
- [`var currentPlaybackTime: TimeInterval`](https://developer.apple.com/documentation/mediaplayer/mpmediaplayback/currentplaybacktime)
- [`func endSeeking()`](https://developer.apple.com/documentation/mediaplayer/mpmediaplayback/endseeking())
- [`var isPreparedToPlay: Bool`](https://developer.apple.com/documentation/mediaplayer/mpmediaplayback/ispreparedtoplay)
- [`func pause()`](https://developer.apple.com/documentation/mediaplayer/mpmediaplayback/pause())
- [`func play()`](https://developer.apple.com/documentation/mediaplayer/mpmediaplayback/play())
- [`func prepareToPlay()`](https://developer.apple.com/documentation/mediaplayer/mpmediaplayback/preparetoplay())
- [`func stop()`](https://developer.apple.com/documentation/mediaplayer/mpmediaplayback/stop())
- [`let MPMediaPlaylistPropertyCloudGlobalID: String`](https://developer.apple.com/documentation/mediaplayer/mpmediaplaylistpropertycloudglobalid)
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/mediaplayer/mpmediapredicate/init(coder:))
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/mediaplayer/mpmediaquery/init(coder:))
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/mediaplayer/mpmediaquerysection/init(coder:))
- [`MPMusicPlayerPlayParameters`](https://developer.apple.com/documentation/mediaplayer/mpmusicplayerplayparameters)
- [`MPMusicPlayerPlayParameters`](https://developer.apple.com/documentation/mediaplayer/mpmusicplayerplayparameters)
- [`var dictionary: [String : Any]`](https://developer.apple.com/documentation/mediaplayer/mpmusicplayerplayparameters/dictionary)
- [`var dictionary: [String : Any]`](https://developer.apple.com/documentation/mediaplayer/mpmusicplayerplayparameters/dictionary)
- [`init?(dictionary: [String : Any])`](https://developer.apple.com/documentation/mediaplayer/mpmusicplayerplayparameters/init(dictionary:))
- [`init?(dictionary: [String : Any])`](https://developer.apple.com/documentation/mediaplayer/mpmusicplayerplayparameters/init(dictionary:))
- [`init(playParametersQueue: [MPMusicPlayerPlayParameters])`](https://developer.apple.com/documentation/mediaplayer/mpmusicplayerplayparametersqueuedescriptor/init(playparametersqueue:))
- [`var playParametersQueue: [MPMusicPlayerPlayParameters]`](https://developer.apple.com/documentation/mediaplayer/mpmusicplayerplayparametersqueuedescriptor/playparametersqueue)
- [`func setEndTime(TimeInterval, forItemWith: MPMusicPlayerPlayParameters)`](https://developer.apple.com/documentation/mediaplayer/mpmusicplayerplayparametersqueuedescriptor/setendtime(_:foritemwith:))
- [`func setStartTime(TimeInterval, forItemWith: MPMusicPlayerPlayParameters)`](https://developer.apple.com/documentation/mediaplayer/mpmusicplayerplayparametersqueuedescriptor/setstarttime(_:foritemwith:))
- [`var startItemPlayParameters: MPMusicPlayerPlayParameters?`](https://developer.apple.com/documentation/mediaplayer/mpmusicplayerplayparametersqueuedescriptor/startitemplayparameters)
- [`class var supportedAnimatedArtworkKeys: [String]`](https://developer.apple.com/documentation/mediaplayer/mpnowplayinginfocenter/supportedanimatedartworkkeys)
- [`func isAutomaticAudibleLanguageOption() -> Bool`](https://developer.apple.com/documentation/mediaplayer/mpnowplayinginfolanguageoption/isautomaticaudiblelanguageoption())
- [`func isAutomaticLegibleLanguageOption() -> Bool`](https://developer.apple.com/documentation/mediaplayer/mpnowplayinginfolanguageoption/isautomaticlegiblelanguageoption())
- [`let MPNowPlayingInfoProperty1x1AnimatedArtwork: String`](https://developer.apple.com/documentation/mediaplayer/mpnowplayinginfoproperty1x1animatedartwork)
- [`let MPNowPlayingInfoProperty3x4AnimatedArtwork: String`](https://developer.apple.com/documentation/mediaplayer/mpnowplayinginfoproperty3x4animatedartwork)
- [`let MPNowPlayingInfoPropertyAdTimeRanges: String`](https://developer.apple.com/documentation/mediaplayer/mpnowplayinginfopropertyadtimeranges)
- [`let MPNowPlayingInfoPropertyAppEntityIdentifiers: String`](https://developer.apple.com/documentation/mediaplayer/mpnowplayinginfopropertyappentityidentifiers)
- [`let MPNowPlayingInfoPropertyCreditsStartTime: String`](https://developer.apple.com/documentation/mediaplayer/mpnowplayinginfopropertycreditsstarttime)
- [`let MPNowPlayingInfoPropertyInternationalStandardRecordingCode: String`](https://developer.apple.com/documentation/mediaplayer/mpnowplayinginfopropertyinternationalstandardrecordingcode)
- [`MPSystemMusicPlayerController`](https://developer.apple.com/documentation/mediaplayer/mpsystemmusicplayercontroller)
- [`func openToPlay(MPMusicPlayerQueueDescriptor)`](https://developer.apple.com/documentation/mediaplayer/mpsystemmusicplayercontroller/opentoplay(_:))
- [`func maximumVolumeSliderImage(for: UIControl.State) -> UIImage?`](https://developer.apple.com/documentation/mediaplayer/mpvolumeview/maximumvolumesliderimage(for:))
- [`func minimumVolumeSliderImage(for: UIControl.State) -> UIImage?`](https://developer.apple.com/documentation/mediaplayer/mpvolumeview/minimumvolumesliderimage(for:))
- [`func setMaximumVolumeSliderImage(UIImage?, for: UIControl.State)`](https://developer.apple.com/documentation/mediaplayer/mpvolumeview/setmaximumvolumesliderimage(_:for:))
- [`func setMinimumVolumeSliderImage(UIImage?, for: UIControl.State)`](https://developer.apple.com/documentation/mediaplayer/mpvolumeview/setminimumvolumesliderimage(_:for:))
- [`func setVolumeThumbImage(UIImage?, for: UIControl.State)`](https://developer.apple.com/documentation/mediaplayer/mpvolumeview/setvolumethumbimage(_:for:))
- [`func volumeThumbImage(for: UIControl.State) -> UIImage?`](https://developer.apple.com/documentation/mediaplayer/mpvolumeview/volumethumbimage(for:))
- [`func volumeThumbRect(forBounds: CGRect, volumeSliderRect: CGRect, value: Float) -> CGRect`](https://developer.apple.com/documentation/mediaplayer/mpvolumeview/volumethumbrect(forbounds:volumesliderrect:value:))

</details>
<!-- /generated:missing -->
