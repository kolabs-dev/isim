// Security & persistence self-test on isim: CommonCrypto, CryptoKit, SQLite3, Keychain (Security), os.Logger.
// Prints PASS/FAIL per check and "security test: N/M passed" last; exits non-zero on failure.
import Foundation

var failures = 0, checks = 0
func check(_ ok: Bool, _ what: String) {
    checks += 1
    if ok { print("PASS  \(what)") } else { failures += 1; print("FAIL  \(what)") }
}

@_silgen_name("isim_test_c_os_log") func cOSLogTest()
@_silgen_name("isim_test_c_os_activity") func cOSActivityTest() -> Int32

@main struct Main {
    static func main() {
        if ProcessInfo.processInfo.environment["SECURITY_TEST_ONLY"] == "pq" {          // test_security_post_quantum (iOS 26)
            if #available(iOS 26.0, *) { postQuantumTests() } else { check(false, "post-quantum CryptoKit needs iOS 26") }
            print("security test: \(checks - failures)/\(checks) passed")
            exit(failures == 0 ? 0 : 1)
        }
        commonCryptoTests()
        cryptoKitTests()
        sqliteTests()
        keychainTests()
        secKeyTests()
        certificateTests()
        cryptoKitExtrasTests()
        if #available(iOS 26.0, *) { postQuantumTests() } else { print("SKIP  post-quantum CryptoKit (iOS 26)") }
        logTests()
        cOSLogTest()
        print("security test: \(checks - failures)/\(checks) passed")
        exit(failures == 0 ? 0 : 1)
    }
}
