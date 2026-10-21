// Binary compatibility for apps built before URLSession.AuthChallengeDisposition became @objc (Apple's
// NSURLSessionAuthChallengeDisposition, which Objective-C delegates such as WKNavigationDelegate's take): resilient
// clients look up enum case tags through these symbols.
__attribute__((used, visibility("default"))) const int $s10Foundation10URLSessionC24AuthChallengeDispositionO13useCredentialyA2EmFWC __asm__("_$s10Foundation10URLSessionC24AuthChallengeDispositionO13useCredentialyA2EmFWC") = 0;
__attribute__((used, visibility("default"))) const int $s10Foundation10URLSessionC24AuthChallengeDispositionO22performDefaultHandlingyA2EmFWC __asm__("_$s10Foundation10URLSessionC24AuthChallengeDispositionO22performDefaultHandlingyA2EmFWC") = 1;
__attribute__((used, visibility("default"))) const int $s10Foundation10URLSessionC24AuthChallengeDispositionO020cancelAuthenticationD0yA2EmFWC __asm__("_$s10Foundation10URLSessionC24AuthChallengeDispositionO020cancelAuthenticationD0yA2EmFWC") = 2;
__attribute__((used, visibility("default"))) const int $s10Foundation10URLSessionC24AuthChallengeDispositionO21rejectProtectionSpaceyA2EmFWC __asm__("_$s10Foundation10URLSessionC24AuthChallengeDispositionO21rejectProtectionSpaceyA2EmFWC") = 3;
