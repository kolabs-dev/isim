// Security & persistence self-test on isim: CommonCrypto, CryptoKit, SQLite3, Keychain (Security), os.Logger.
// Prints PASS/FAIL per check and "security test: N/M passed" last; exits non-zero on failure.
import Foundation

var failures = 0, checks = 0
func check(_ ok: Bool, _ what: String) {
    checks += 1
    if ok { print("PASS  \(what)") } else { failures += 1; print("FAIL  \(what)") }
}

@main struct Main {
    static func main() {
        commonCryptoTests()
        cryptoKitTests()
        sqliteTests()
        print("security test: \(checks - failures)/\(checks) passed")
        exit(failures == 0 ? 0 : 1)
    }
}
