/* UniformTypeIdentifiers.framework: the UTCoreTypes.h constants. The UTType class is the Swift overlay's UTTypeReference
   (@objc(UTType), re-exported); its system types fill these when the framework loads. */
#import <Foundation/Foundation.h>
#import <UniformTypeIdentifiers/UTType.h>   /* not UTCoreTypes.h: this file defines its constants (writable, filled at load) */
#import <UniformTypeIdentifiers/UTTagClass.h>

NSString *const UTTagClassFilenameExtension = @"public.filename-extension";
NSString *const UTTagClassMIMEType = @"public.mime-type";

UTType *UTType3DContent;
UTType *UTTypeAHAP;
UTType *UTTypeAIFF;
UTType *UTTypeARReferenceObject;
UTType *UTTypeAVI;
UTType *UTTypeAliasFile;
UTType *UTTypeAppleArchive;
UTType *UTTypeAppleProtectedMPEG4Audio;
UTType *UTTypeAppleProtectedMPEG4Video;
UTType *UTTypeAppleScript;
UTType *UTTypeApplication;
UTType *UTTypeApplicationBundle;
UTType *UTTypeApplicationExtension;
UTType *UTTypeArchive;
UTType *UTTypeAssemblyLanguageSource;
UTType *UTTypeAudio;
UTType *UTTypeAudiovisualContent;
UTType *UTTypeBMP;
UTType *UTTypeBZ2;
UTType *UTTypeBinaryPropertyList;
UTType *UTTypeBookmark;
UTType *UTTypeBundle;
UTType *UTTypeCHeader;
UTType *UTTypeCPlusPlusHeader;
UTType *UTTypeCPlusPlusSource;
UTType *UTTypeCSS;
UTType *UTTypeCSource;
UTType *UTTypeCalendarEvent;
UTType *UTTypeCommaSeparatedText;
UTType *UTTypeCompositeContent;
UTType *UTTypeContact;
UTType *UTTypeContent;
UTType *UTTypeDNG;
UTType *UTTypeData;
UTType *UTTypeDatabase;
UTType *UTTypeDelimitedText;
UTType *UTTypeDirectory;
UTType *UTTypeDiskImage;
UTType *UTTypeEPUB;
UTType *UTTypeEXE;
UTType *UTTypeEXR;
UTType *UTTypeEmailMessage;
UTType *UTTypeExecutable;
UTType *UTTypeFileURL;
UTType *UTTypeFlatRTFD;
UTType *UTTypeFolder;
UTType *UTTypeFont;
UTType *UTTypeFramework;
UTType *UTTypeGIF;
UTType *UTTypeGZIP;
UTType *UTTypeGeoJSON;
UTType *UTTypeHEIC;
UTType *UTTypeHEICS;
UTType *UTTypeHEIF;
UTType *UTTypeHTML;
UTType *UTTypeICNS;
UTType *UTTypeICO;
UTType *UTTypeImage;
UTType *UTTypeInternetLocation;
UTType *UTTypeInternetShortcut;
UTType *UTTypeItem;
UTType *UTTypeJPEG;
UTType *UTTypeJPEGXL;
UTType *UTTypeJSON;
UTType *UTTypeJavaScript;
UTType *UTTypeLinkPresentationMetadata;
UTType *UTTypeLivePhoto;
UTType *UTTypeLog;
UTType *UTTypeM3UPlaylist;
UTType *UTTypeMIDI;
UTType *UTTypeMP3;
UTType *UTTypeMPEG;
UTType *UTTypeMPEG2TransportStream;
UTType *UTTypeMPEG2Video;
UTType *UTTypeMPEG4Audio;
UTType *UTTypeMPEG4Movie;
UTType *UTTypeMakefile;
UTType *UTTypeMarkdown;
UTType *UTTypeMessage;
UTType *UTTypeMountPoint;
UTType *UTTypeMovie;
UTType *UTTypeOSAScript;
UTType *UTTypeOSAScriptBundle;
UTType *UTTypeObjectiveCPlusPlusSource;
UTType *UTTypeObjectiveCSource;
UTType *UTTypePDF;
UTType *UTTypePHPScript;
UTType *UTTypePKCS12;
UTType *UTTypePNG;
UTType *UTTypePackage;
UTType *UTTypePerlScript;
UTType *UTTypePlainText;
UTType *UTTypePlaylist;
UTType *UTTypePluginBundle;
UTType *UTTypePresentation;
UTType *UTTypePropertyList;
UTType *UTTypePythonScript;
UTType *UTTypeQuickLookGenerator;
UTType *UTTypeQuickTimeMovie;
UTType *UTTypeRAWImage;
UTType *UTTypeRTF;
UTType *UTTypeRTFD;
UTType *UTTypeRealityFile;
UTType *UTTypeResolvable;
UTType *UTTypeRubyScript;
UTType *UTTypeSVG;
UTType *UTTypeSceneKitScene;
UTType *UTTypeScript;
UTType *UTTypeShazamCustomCatalog;
UTType *UTTypeShazamSignature;
UTType *UTTypeShellScript;
UTType *UTTypeSourceCode;
UTType *UTTypeSpotlightImporter;
UTType *UTTypeSpreadsheet;
UTType *UTTypeSwiftSource;
UTType *UTTypeSymbolicLink;
UTType *UTTypeSystemPreferencesPane;
UTType *UTTypeTIFF;
UTType *UTTypeTabSeparatedText;
UTType *UTTypeTarArchive;
UTType *UTTypeText;
UTType *UTTypeToDoItem;
UTType *UTTypeURL;
UTType *UTTypeURLBookmarkData;
UTType *UTTypeUSD;
UTType *UTTypeUSDZ;
UTType *UTTypeUTF16ExternalPlainText;
UTType *UTTypeUTF16PlainText;
UTType *UTTypeUTF8PlainText;
UTType *UTTypeUTF8TabSeparatedText;
UTType *UTTypeUnixExecutable;
UTType *UTTypeVCard;
UTType *UTTypeVideo;
UTType *UTTypeVolume;
UTType *UTTypeWAV;
UTType *UTTypeWebArchive;
UTType *UTTypeWebP;
UTType *UTTypeX509Certificate;
UTType *UTTypeXML;
UTType *UTTypeXMLPropertyList;
UTType *UTTypeXPCService;
UTType *UTTypeYAML;
UTType *UTTypeZIP;

static const struct { UTType **slot; const char *identifier; } core_types[] = {
    { &UTType3DContent, "public.3d-content" },
    { &UTTypeAHAP, "com.apple.haptics.ahap" },
    { &UTTypeAIFF, "public.aiff-audio" },
    { &UTTypeARReferenceObject, "com.apple.arobject" },
    { &UTTypeAVI, "public.avi" },
    { &UTTypeAliasFile, "com.apple.alias-file" },
    { &UTTypeAppleArchive, "com.apple.archive" },
    { &UTTypeAppleProtectedMPEG4Audio, "com.apple.protected-mpeg-4-audio" },
    { &UTTypeAppleProtectedMPEG4Video, "com.apple.protected-mpeg-4-video" },
    { &UTTypeAppleScript, "com.apple.applescript.text" },
    { &UTTypeApplication, "com.apple.application" },
    { &UTTypeApplicationBundle, "com.apple.application-bundle" },
    { &UTTypeApplicationExtension, "com.apple.application-and-system-extension" },
    { &UTTypeArchive, "public.archive" },
    { &UTTypeAssemblyLanguageSource, "public.assembly-source" },
    { &UTTypeAudio, "public.audio" },
    { &UTTypeAudiovisualContent, "public.audiovisual-content" },
    { &UTTypeBMP, "com.microsoft.bmp" },
    { &UTTypeBZ2, "public.bzip2-archive" },
    { &UTTypeBinaryPropertyList, "com.apple.binary-property-list" },
    { &UTTypeBookmark, "public.bookmark" },
    { &UTTypeBundle, "com.apple.bundle" },
    { &UTTypeCHeader, "public.c-header" },
    { &UTTypeCPlusPlusHeader, "public.c-plus-plus-header" },
    { &UTTypeCPlusPlusSource, "public.c-plus-plus-source" },
    { &UTTypeCSS, "public.css" },
    { &UTTypeCSource, "public.c-source" },
    { &UTTypeCalendarEvent, "public.calendar-event" },
    { &UTTypeCommaSeparatedText, "public.comma-separated-values-text" },
    { &UTTypeCompositeContent, "public.composite-content" },
    { &UTTypeContact, "public.contact" },
    { &UTTypeContent, "public.content" },
    { &UTTypeDNG, "com.adobe.raw-image" },
    { &UTTypeData, "public.data" },
    { &UTTypeDatabase, "public.database" },
    { &UTTypeDelimitedText, "public.delimited-values-text" },
    { &UTTypeDirectory, "public.directory" },
    { &UTTypeDiskImage, "public.disk-image" },
    { &UTTypeEPUB, "org.idpf.epub-container" },
    { &UTTypeEXE, "com.microsoft.windows-executable" },
    { &UTTypeEXR, "com.ilm.openexr-image" },
    { &UTTypeEmailMessage, "public.email-message" },
    { &UTTypeExecutable, "public.executable" },
    { &UTTypeFileURL, "public.file-url" },
    { &UTTypeFlatRTFD, "com.apple.flat-rtfd" },
    { &UTTypeFolder, "public.folder" },
    { &UTTypeFont, "public.font" },
    { &UTTypeFramework, "com.apple.framework" },
    { &UTTypeGIF, "com.compuserve.gif" },
    { &UTTypeGZIP, "org.gnu.gnu-zip-archive" },
    { &UTTypeGeoJSON, "public.geojson" },
    { &UTTypeHEIC, "public.heic" },
    { &UTTypeHEICS, "public.heics" },
    { &UTTypeHEIF, "public.heif" },
    { &UTTypeHTML, "public.html" },
    { &UTTypeICNS, "com.apple.icns" },
    { &UTTypeICO, "com.microsoft.ico" },
    { &UTTypeImage, "public.image" },
    { &UTTypeInternetLocation, "com.apple.internet-location" },
    { &UTTypeInternetShortcut, "com.microsoft.internet-shortcut" },
    { &UTTypeItem, "public.item" },
    { &UTTypeJPEG, "public.jpeg" },
    { &UTTypeJPEGXL, "public.jpeg-xl" },
    { &UTTypeJSON, "public.json" },
    { &UTTypeJavaScript, "com.netscape.javascript-source" },
    { &UTTypeLinkPresentationMetadata, "com.apple.linkpresentation.metadata" },
    { &UTTypeLivePhoto, "com.apple.live-photo" },
    { &UTTypeLog, "com.apple.log" },
    { &UTTypeM3UPlaylist, "public.m3u-playlist" },
    { &UTTypeMIDI, "public.midi-audio" },
    { &UTTypeMP3, "public.mp3" },
    { &UTTypeMPEG, "public.mpeg" },
    { &UTTypeMPEG2TransportStream, "public.mpeg-2-transport-stream" },
    { &UTTypeMPEG2Video, "public.mpeg-2-video" },
    { &UTTypeMPEG4Audio, "public.mpeg-4-audio" },
    { &UTTypeMPEG4Movie, "public.mpeg-4" },
    { &UTTypeMakefile, "public.make-source" },
    { &UTTypeMarkdown, "net.daringfireball.markdown" },
    { &UTTypeMessage, "public.message" },
    { &UTTypeMountPoint, "com.apple.mount-point" },
    { &UTTypeMovie, "public.movie" },
    { &UTTypeOSAScript, "com.apple.applescript.script" },
    { &UTTypeOSAScriptBundle, "com.apple.applescript.script-bundle" },
    { &UTTypeObjectiveCPlusPlusSource, "public.objective-c-plus-plus-source" },
    { &UTTypeObjectiveCSource, "public.objective-c-source" },
    { &UTTypePDF, "com.adobe.pdf" },
    { &UTTypePHPScript, "public.php-script" },
    { &UTTypePKCS12, "com.rsa.pkcs-12" },
    { &UTTypePNG, "public.png" },
    { &UTTypePackage, "com.apple.package" },
    { &UTTypePerlScript, "public.perl-script" },
    { &UTTypePlainText, "public.plain-text" },
    { &UTTypePlaylist, "public.playlist" },
    { &UTTypePluginBundle, "com.apple.plugin" },
    { &UTTypePresentation, "public.presentation" },
    { &UTTypePropertyList, "com.apple.property-list" },
    { &UTTypePythonScript, "public.python-script" },
    { &UTTypeQuickLookGenerator, "com.apple.quicklook-generator" },
    { &UTTypeQuickTimeMovie, "com.apple.quicktime-movie" },
    { &UTTypeRAWImage, "public.camera-raw-image" },
    { &UTTypeRTF, "public.rtf" },
    { &UTTypeRTFD, "com.apple.rtfd" },
    { &UTTypeRealityFile, "com.apple.reality" },
    { &UTTypeResolvable, "com.apple.resolvable" },
    { &UTTypeRubyScript, "public.ruby-script" },
    { &UTTypeSVG, "public.svg-image" },
    { &UTTypeSceneKitScene, "com.apple.scenekit.scene" },
    { &UTTypeScript, "public.script" },
    { &UTTypeShazamCustomCatalog, "com.shazam.custom-catalog" },
    { &UTTypeShazamSignature, "com.shazam.signature" },
    { &UTTypeShellScript, "public.shell-script" },
    { &UTTypeSourceCode, "public.source-code" },
    { &UTTypeSpotlightImporter, "com.apple.metadata-importer" },
    { &UTTypeSpreadsheet, "public.spreadsheet" },
    { &UTTypeSwiftSource, "public.swift-source" },
    { &UTTypeSymbolicLink, "public.symlink" },
    { &UTTypeSystemPreferencesPane, "com.apple.systempreference.prefpane" },
    { &UTTypeTIFF, "public.tiff" },
    { &UTTypeTabSeparatedText, "public.tab-separated-values-text" },
    { &UTTypeTarArchive, "public.tar-archive" },
    { &UTTypeText, "public.text" },
    { &UTTypeToDoItem, "public.to-do-item" },
    { &UTTypeURL, "public.url" },
    { &UTTypeURLBookmarkData, "com.apple.bookmark" },
    { &UTTypeUSD, "com.pixar.universal-scene-description" },
    { &UTTypeUSDZ, "com.pixar.universal-scene-description-mobile" },
    { &UTTypeUTF16ExternalPlainText, "public.utf16-external-plain-text" },
    { &UTTypeUTF16PlainText, "public.utf16-plain-text" },
    { &UTTypeUTF8PlainText, "public.utf8-plain-text" },
    { &UTTypeUTF8TabSeparatedText, "public.utf8-tab-separated-values-text" },
    { &UTTypeUnixExecutable, "public.unix-executable" },
    { &UTTypeVCard, "public.vcard" },
    { &UTTypeVideo, "public.video" },
    { &UTTypeVolume, "public.volume" },
    { &UTTypeWAV, "com.microsoft.waveform-audio" },
    { &UTTypeWebArchive, "com.apple.webarchive" },
    { &UTTypeWebP, "org.webmproject.webp" },
    { &UTTypeX509Certificate, "public.x509-certificate" },
    { &UTTypeXML, "public.xml" },
    { &UTTypeXMLPropertyList, "com.apple.xml-property-list" },
    { &UTTypeXPCService, "com.apple.xpc-service" },
    { &UTTypeYAML, "public.yaml" },
    { &UTTypeZIP, "public.zip-archive" },
};
__attribute__((constructor)) static void core_types_init(void) {
    for (size_t i = 0; i < sizeof core_types / sizeof core_types[0]; i++)
        *core_types[i].slot = [[UTType typeWithIdentifier:@(core_types[i].identifier)] retain];   /* MRC: kept for good */
}
