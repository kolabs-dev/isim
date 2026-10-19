// HelloTextKit, -undo: undo while editing text on isim (issue #244) — a UITextField and a UITextView register their edits with
// the responder chain's undoManager: typing coalesces into one "Typing" action, paste / cut / delete are their own
// actions, Cmd-Z / Shift-Cmd-Z and Shake to Undo undo and redo them, and setting the text in code clears them.
// Undo / Redo buttons call the first responder's undoManager; each change logs the state for the test.
import UIKit

final class UndoViewController: UIViewController, UITextFieldDelegate, UITextViewDelegate {
    let field = UITextField(frame: CGRect(x: 20, y: 80, width: 362, height: 40))
    let notes = UITextView(frame: CGRect(x: 20, y: 130, width: 362, height: 120))
    weak var focused: UIResponder?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        field.borderStyle = .roundedRect
        field.placeholder = "Field"
        field.accessibilityIdentifier = "field"
        field.delegate = self
        field.addTarget(self, action: #selector(changed), for: .editingChanged)
        notes.layer.borderWidth = 1; notes.layer.borderColor = UIColor.separator.cgColor
        notes.font = .systemFont(ofSize: 17)
        notes.accessibilityIdentifier = "notes"
        notes.delegate = self
        view.addSubview(field); view.addSubview(notes)
        for (i, (title, action)) in [("Undo", #selector(undo)), ("Redo", #selector(redo)), ("Reset", #selector(reset))].enumerated() {
            let b = UIButton(type: .system)
            b.setTitle(title, for: .normal)
            b.frame = CGRect(x: 20 + CGFloat(i) * 110, y: 270, width: 100, height: 44)
            b.accessibilityIdentifier = title.lowercased()
            b.addTarget(self, action: action, for: .touchUpInside)
            view.addSubview(b)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(undone), name: .NSUndoManagerDidUndoChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(undone), name: .NSUndoManagerDidRedoChange, object: nil)
        print("undo managers field=\(field.undoManager != nil) same=\(field.undoManager === view.window?.undoManager || view.window == nil)")
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("undo managers window=\(field.undoManager === view.window?.undoManager) responder=\(notes.undoManager === field.undoManager)")
    }

    func log(_ why: String) {
        let um = focused?.undoManager ?? field.undoManager
        print("state \(why) field='\(field.text ?? "")' notes='\(notes.text ?? "")' canUndo=\(um?.canUndo ?? false) " +
              "undo='\(um?.undoActionName ?? "")' canRedo=\(um?.canRedo ?? false) redo='\(um?.redoActionName ?? "")'")
    }
    @objc func changed() { log("edit") }
    func textFieldDidBeginEditing(_ textField: UITextField) { focused = textField }
    func textViewDidBeginEditing(_ textView: UITextView) { focused = textView }
    func textViewDidChange(_ textView: UITextView) { log("edit") }
    @objc func undone() { DispatchQueue.main.async { self.log("undo") } }
    @objc func undo() { focused?.undoManager?.undo() }
    @objc func redo() { focused?.undoManager?.redo() }
    @objc func reset() {
        if focused === notes { notes.text = "Reset" } else { field.text = "Reset" }
        log("reset")
    }
}
