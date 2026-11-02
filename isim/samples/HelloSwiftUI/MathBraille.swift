// HelloSwiftUI, -axmath: more of the Accessibility framework on isim (issue #426). A UIKit label conforming to
// AXMathExpressionProvider gives VoiceOver the quadratic formula, read as speech; on iOS 26 a phrase is translated to
// braille with the device language's default table (liblouis on the host) and back; on iOS 18.2 the app asks for a
// feature override session without the entitlement (refused with .appNotEntitled). It prints what the UI test checks.
import SwiftUI
import UIKit
import Accessibility

/// x = (−b ± √(b² − 4ac)) / 2a
@available(iOS 18.2, *)
final class EquationLabel: UILabel, AXMathExpressionProvider {
    func accessibilityMathExpression() -> AXMathExpression? {
        let b2 = AXMathExpressionSubSuperscript(baseExpression: [AXMathExpressionIdentifier(content: "b")], subscriptExpressions: [],
                                                superscriptExpressions: [AXMathExpressionNumber(content: "2")])
        let disc = AXMathExpressionRoot(radicandExpressions: [b2, AXMathExpressionOperator(content: "−"), AXMathExpressionNumber(content: "4"),
                                                             AXMathExpressionIdentifier(content: "a"), AXMathExpressionIdentifier(content: "c")],
                                        rootIndexExpression: AXMathExpressionNumber(content: "2"))
        let numerator = AXMathExpressionRow(expressions: [AXMathExpressionOperator(content: "−"), AXMathExpressionIdentifier(content: "b"),
                                                          AXMathExpressionOperator(content: "±"), disc])
        let fraction = AXMathExpressionFraction(numeratorExpression: numerator,
                                                denimonatorExpression: AXMathExpressionRow(expressions: [AXMathExpressionNumber(content: "2"), AXMathExpressionIdentifier(content: "a")]))
        return AXMathExpressionRow(expressions: [AXMathExpressionIdentifier(content: "x"), AXMathExpressionOperator(content: "="), fraction])
    }
}
private struct Equation: UIViewRepresentable {
    func makeUIView(context: Context) -> UILabel {
        let l: UILabel
        if #available(iOS 18.2, *) { l = EquationLabel() } else { l = UILabel() }
        l.text = "x = (−b ± √(b² − 4ac)) / 2a"
        l.font = .systemFont(ofSize: 20)
        l.accessibilityLabel = "Quadratic formula"
        l.accessibilityIdentifier = "equation"
        return l
    }
    func updateUIView(_ uiView: UILabel, context: Context) {}
}

struct MathBrailleDemo: View {
    @State private var braille = "–"
    @State private var override = "–"
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Quadratic formula").font(.headline)
            Equation().frame(height: 40)
            Text("Braille").font(.headline)
            Text(braille).font(.system(size: 28)).accessibilityIdentifier("braille")
            Button("Feature override") {
                guard #available(iOS 18.2, *) else { override = "needs iOS 18.2"; print("ax override needs iOS 18.2"); return }
                do {
                    _ = try AXFeatureOverrideSessionManager.sharedInstance.beginOverrideSession(enabling: .voiceOver, disabling: [])
                    override = "began"
                } catch {
                    let e = error as NSError
                    override = "refused"
                    print("ax override error \(e.domain) \(e.code) notEntitled=\(e.code == AXFeatureOverrideSessionError.appNotEntitled.rawValue)")
                }
            }
            .accessibilityIdentifier("override")
            Text(override).accessibilityIdentifier("override-status")
            Spacer()
        }
        .padding()
        .onAppear {
            guard #available(iOS 26.0, *) else { print("ax braille needs iOS 26"); return }
            let tables = AXBrailleTable.tables(for: Locale(identifier: "en_US"))
            guard let table = AXBrailleTable.defaultTable(for: Locale(identifier: "en_US")) else { print("ax braille no tables"); return }
            let t = AXBrailleTranslator(brailleTable: table)
            let r = t.translatePrintText("Hello world")
            let back = t.backTranslateBraille(r.resultString)
            let last = r.resultString.index(before: r.resultString.endIndex)
            let src = r.inputIndex(forResultIndex: last).map { "Hello world"[$0] } ?? "?"
            print("ax braille \(tables.count > 1) \(table.identifier) \(table.language.languageCode?.identifier ?? "-") eight=\(table.isEightDot) \(r.resultString) back=\(back.resultString) last=\(src)")
            braille = r.resultString
        }
    }
}
