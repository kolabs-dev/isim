// UniformTypeIdentifiers and CoreTransferable from Swift (UTTypesTest.app, issue #278): the app's Info.plist type
// declarations (exported and imported), the system types, tags and conformance, the Objective-C bridge, and
// Transferable's Codable representation, visibility, suggested file names and exporting conditions.
import Foundation
import UniformTypeIdentifiers
import CoreTransferable

var failures = 0, checks = 0
func check(_ ok: @autoclosure () -> Bool, _ what: String) {
    checks += 1
    if ok() { print("PASS  \(what)") } else { failures += 1; print("FAIL  \(what)") }
}

extension UTType {
    static let recipe = UTType(exportedAs: "dev.isim.recipe")
    static let exampleNote = UTType(importedAs: "com.example.note")
}

struct Recipe: Codable, Transferable, Equatable {
    var name: String
    var minutes: Int
    var secret = false
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .recipe)
        DataRepresentation(exportedContentType: .plainText) { r in Data("\(r.name), \(r.minutes) min".utf8) }
            .suggestedFileName { $0.name }
            .exportingCondition { !$0.secret }
        ProxyRepresentation(exporting: \.name)
            .visibility(.ownProcess)
    }
}
struct Settings: Codable, Transferable, Equatable {
    var volume: Int
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .propertyList, encoder: PropertyListEncoder(), decoder: PropertyListDecoder())
            .suggestedFileName("Settings")
    }
}

func declarations() {
    let r = UTType.recipe
    check(r.conforms(to: .json) && r.conforms(to: .text) && r.conforms(to: .data), "exported type: its declared conformance")
    check(r.preferredFilenameExtension == "recipe" && r.preferredMIMEType == "application/x-isim-recipe", "exported type: its tags")
    check(r.localizedDescription == "Recipe" && r.isDeclared && !r.isDynamic && !r.isSystemDeclared, "exported type: declared, described")
    check(UTType(filenameExtension: "recipe") == r && UTType(filenameExtension: "RECIPE", conformingTo: .json) == r, "by filename extension")
    check(UTType(mimeType: "application/x-isim-recipe") == r, "by MIME type")
    check(UTType("dev.isim.recipe")?.conforms(to: .json) == true, "by identifier")
    let n = UTType.exampleNote
    check(n.conforms(to: .plainText) && n.preferredFilenameExtension == "exnote" && n.localizedDescription == "Example Note", "imported type")
    let undeclared = UTType(exportedAs: "dev.isim.undeclared", conformingTo: .image)
    check(undeclared.conforms(to: .image) && !undeclared.isDeclared && undeclared.preferredFilenameExtension == nil, "undeclared: the given parent")
    check(UTType.types(tag: "recipe", tagClass: .filenameExtension, conformingTo: nil) == [r], "types(tag:tagClass:conformingTo:)")
    check(r.tags[.filenameExtension] == ["recipe"] && r.tags[.mimeType] == ["application/x-isim-recipe"], "tags by tag class")
}

func systemTypes() {
    check(UTType.markdown.identifier == "net.daringfireball.markdown" && UTType(filenameExtension: "md") == .markdown && UTType.markdown.conforms(to: .plainText), "markdown")
    check(UTType(filenameExtension: "yml") == .yaml && UTType.yaml.conforms(to: .text), "yaml")
    check(UTType(filenameExtension: "gz") == .gzip && UTType.gzip.conforms(to: .archive) && UTType(mimeType: "application/gzip") == .gzip, "gzip")
    check(UTType(filenameExtension: "tar") == .tarArchive && UTType(filenameExtension: "bz2") == .bz2, "tar, bz2")
    check(UTType(mimeType: "application/epub+zip") == .epub && UTType.epub.conforms(to: .compositeContent), "epub")
    check(UTType(filenameExtension: "avi") == .avi && UTType.avi.conforms(to: .movie) && UTType.avi.conforms(to: .audiovisualContent), "avi")
    check(UTType.spreadsheet.conforms(to: .content) && UTType.presentation.conforms(to: .compositeContent), "spreadsheet, presentation")
    check(UTType(filenameExtension: "py") == .pythonScript && UTType.pythonScript.conforms(to: .script) && UTType.pythonScript.conforms(to: .sourceCode), "scripts")
    check(UTType(filenameExtension: "csv") == .commaSeparatedText && UTType.commaSeparatedText.conforms(to: .delimitedText), "delimited text")
    check(UTType(filenameExtension: "usdz") == .usdz && UTType.usdz.conforms(to: .threeDContent), "3D")
    check(UTType(filenameExtension: "cer") == .x509Certificate && UTType(filenameExtension: "p12") == .pkcs12, "certificates")
    check(UTType.applicationBundle.conforms(to: .bundle) && UTType.applicationBundle.conforms(to: .directory) && UTType.applicationBundle.preferredFilenameExtension == "app", "bundles")
    check(UTType.markdown.isSystemDeclared && UTType.markdown.isPublicType == false && UTType.yaml.isPublicType, "system and public")
    let dyn = UTType(filenameExtension: "zzqq")
    check(dyn?.isDynamic == true && dyn?.isDeclared == false, "an unknown extension: dynamic")
}

func bridging() {
    let ref = UTType.png as UTTypeReference
    check(ref.identifier == "public.png" && ref.conforms(to: UTType.image as UTTypeReference), "UTTypeReference (Objective-C UTType)")
    check((ref as UTType) == .png, "bridged back")
    check(NSStringFromClass(UTTypeReference.self) == "UTType", "its Objective-C name")
}

func transferables() async {
    let r = Recipe(name: "Pancakes", minutes: 20)
    check(Recipe.exportedContentTypes == [.recipe, .plainText, .plainText] && Recipe.importedContentTypes == [.recipe], "content types in order")
    do {
        let json = try await r.exported(as: .recipe)
        let back = try JSONDecoder().decode(Recipe.self, from: json)
        check(back == r, "CodableRepresentation: JSON out")
        let imported = try await Recipe._isimImport(json, contentType: .recipe)
        check(imported == r, "CodableRepresentation: JSON in")
        let text = try await r.exported(as: .plainText)
        check(String(decoding: text, as: UTF8.self) == "Pancakes, 20 min", "DataRepresentation")
    } catch { check(false, "export: \(error)") }
    check(r._isimSuggestedFileName(for: .plainText) == "Pancakes.txt", "suggestedFileName with the type's extension")
    let secret = Recipe(name: "Family", minutes: 5, secret: true)
    check(secret._isimExportedContentTypes == [.recipe, .plainText], "exportingCondition leaves the representation out")
    do {
        let proxied = try await secret.exported(as: .plainText)
        check(proxied == Data("Family".utf8), "the next representation (the proxy) instead")
    } catch { check(false, "secret export: \(error)") }
    check(Recipe._isimEntries.last?.visibility == .ownProcess && Recipe._isimEntries.first?.visibility == .all, "visibility")
    let s = Settings(volume: 7)
    do {
        let data = try await s.exported(as: .propertyList)
        check(String(decoding: data.prefix(6), as: UTF8.self) == "bplist" || String(decoding: data.prefix(5), as: UTF8.self) == "<?xml", "a custom encoder (property list)")
        let decoded = try await Settings._isimImport(data, contentType: .propertyList)
        check(decoded == s, "a custom decoder")
    } catch { check(false, "settings: \(error)") }
    check(s._isimSuggestedFileName(for: .propertyList) == "Settings.plist", "a fixed suggested file name")
}

@main enum UTTypesTest {
    static func main() async {
        declarations()
        systemTypes()
        bridging()
        await transferables()
        print("uttypes: \(checks - failures)/\(checks) passed")
        exit(failures == 0 ? 0 : 1)
    }
}
