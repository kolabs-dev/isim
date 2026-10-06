// An NSException raised by Objective-C code called from Swift cannot be caught by Swift (`do/catch`
// only sees Swift errors), exactly as on iOS: the app terminates with the uncaught-exception report.
import Foundation

struct NotThrown: Error {}

@main struct Main {
    static func main() {
        let mode = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "range"
        print("swift mode \(mode)")
        do {
            if Int.random(in: 0..<2) == 5 { throw NotThrown() }
            if mode == "raise" {
                NSException(name: NSInvalidArgumentException, reason: "raised from Swift", userInfo: nil).raise()
            } else {
                let array = [1, 2] as NSArray
                print("got \(array.object(at: 5))")
            }
        } catch {
            print("SWIFT CAUGHT \(error)")
        }
        print("NOT REACHED")
    }
}
