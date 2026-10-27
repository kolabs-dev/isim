// isim Translation (self-authored, Apple's API names): the SwiftUI side — translationTask, which hands a view a session
// to translate with, and translationPresentation, the system's translation sheet (a popover on iPad) over isim's host
// engine (Translation.swift).
import SwiftUI
import UIKit

@available(iOS 18.0, macOS 15.0, *)
extension View {
    /// runs `action` with a session for the configuration when the view appears and whenever the configuration changes
    /// (`invalidate()` included); nil runs nothing
    public func translationTask(_ configuration: TranslationSession.Configuration?, action: @escaping (TranslationSession) async -> Void) -> some View {
        modifier(_TranslationTask(configuration: configuration, action: action))
    }
    /// runs `action` once with a session for the pair when the view appears
    public func translationTask(source: Locale.Language? = nil, target: Locale.Language? = nil,
                                action: @escaping (TranslationSession) async -> Void) -> some View {
        modifier(_TranslationTask(configuration: TranslationSession.Configuration(source: source, target: target), action: action))
    }
    @available(iOS 26.4, macOS 26.4, *)
    public func translationTask(source: Locale.Language? = nil, target: Locale.Language? = nil, preferredStrategy: TranslationSession.Strategy,
                                action: @escaping (TranslationSession) async -> Void) -> some View {
        modifier(_TranslationTask(configuration: TranslationSession.Configuration(source: source, target: target, preferredStrategy: preferredStrategy),
                                  action: action))
    }
}

@available(iOS 17.4, macOS 14.4, *)
extension View {
    /// presents the system's translation of `text`: a sheet on iPhone, a popover on iPad; with `replacementAction` it
    /// offers to replace the text with its translation
    public func translationPresentation(isPresented: Binding<Bool>, text: String, attachmentAnchor: PopoverAttachmentAnchor = .rect(.bounds),
                                        arrowEdge: Edge = .top, replacementAction: ((String) -> Void)? = nil) -> some View {
        popover(isPresented: isPresented, attachmentAnchor: attachmentAnchor, arrowEdge: arrowEdge) {
            _TranslationCard(text: text, isPresented: isPresented, replacementAction: replacementAction)
        }
    }
}

@available(iOS 18.0, macOS 15.0, *)
struct _TranslationTask: ViewModifier {
    let configuration: TranslationSession.Configuration?
    let action: (TranslationSession) async -> Void
    func body(content: Content) -> some View {
        content.task(id: configuration) {
            guard let c = configuration else { return }
            await action(TranslationSession(source: c.source, target: c.target, canRequestDownloads: true, strategy: c._strategy))
        }
    }
}

/// a language's name in the user's language ("Spanish")
func _translationLanguageName(_ l: Locale.Language) -> String {
    let code = l.languageCode?.identifier ?? l.minimalIdentifier
    return Locale.current.localizedString(forLanguageCode: code)?.capitalized ?? code
}

/// the translation sheet: the text and its language, the translation into the user's language, Copy and Replace
@available(iOS 17.4, macOS 14.4, *)
struct _TranslationCard: View {
    struct Result { let sourceLanguage: Locale.Language, targetLanguage: Locale.Language, targetText: String }
    let text: String
    let isPresented: Binding<Bool>
    let replacementAction: ((String) -> Void)?
    @State private var response: Result?
    @State private var failure: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Translate").font(.headline)
                Spacer()
                Button("Done") { isPresented.wrappedValue = false }.fontWeight(.semibold).accessibilityIdentifier("translation.done")
            }
            .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 12)
            VStack(alignment: .leading, spacing: 6) {
                Text(response.map { _translationLanguageName($0.sourceLanguage) } ?? " ").font(.footnote).foregroundStyle(.secondary)
                Text(text).font(.title3).accessibilityIdentifier("translation.source")
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
            Divider().padding(.horizontal, 20)
            VStack(alignment: .leading, spacing: 6) {
                if let response {
                    Text(_translationLanguageName(response.targetLanguage)).font(.footnote).foregroundStyle(Color.accentColor)
                    Text(response.targetText).font(.title3).foregroundStyle(Color.accentColor).accessibilityIdentifier("translation.target")
                } else if let failure {
                    Text("Translation Unavailable").font(.footnote).foregroundStyle(.secondary)
                    Text(failure).font(.body).foregroundStyle(.secondary).accessibilityIdentifier("translation.unavailable")
                } else {
                    ProgressView()
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
            Spacer(minLength: 12)
            VStack(spacing: 0) {
                if let response, let replacementAction {
                    _TranslationAction(title: "Replace with Translation", symbol: "text.badge.checkmark", id: "translation.replace") {
                        replacementAction(response.targetText); isPresented.wrappedValue = false
                    }
                    Divider().padding(.leading, 52)
                }
                _TranslationAction(title: "Copy Translation", symbol: "doc.on.doc", id: "translation.copy") {
                    if let response { UIPasteboard.general.string = response.targetText }
                }
                .disabled(response == nil)
            }
            .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 20).padding(.bottom, 20)
        }
        .frame(minWidth: 320, idealWidth: 375, minHeight: 360, alignment: .top)
        .background(Color(UIColor.systemGroupedBackground))
        .presentationDetents([.medium, .large])
        .task {
            do {
                let r = try await _TranslationHost.run([text], source: nil, target: _TranslationHost.code(_TranslationHost.preferred))
                response = Result(sourceLanguage: _TranslationHost.language(r.source), targetLanguage: _TranslationHost.language(r.target),
                                  targetText: r.texts.first ?? "")
            } catch let f as _TranslationFailure {
                failure = f.reason ?? "Translation between these languages is not supported."
            } catch { failure = error.localizedDescription }
        }
    }
}

struct _TranslationAction: View {
    let title: String, symbol: String, id: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol).frame(width: 22)
                Text(title)
                Spacer()
            }
            .padding(.horizontal, 16).frame(height: 48).contentShape(Rectangle())
        }
        .accessibilityIdentifier(id)
    }
}
