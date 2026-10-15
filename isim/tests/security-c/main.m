// Certificates, trust and identities from C and Objective-C (issue #229), on the test PKI of tests/security/pki
// (make_fixtures.py, make_trust_fixtures.py): SecCertificate, SecPolicy, SecTrust (custom anchors, verify date,
// host names, exceptions, the deprecated SecTrustEvaluate), SecIdentity and SecPKCS12Import. Prints PASS/FAIL per
// check, then "security c test: N/M passed"; the exit code is the number of failures.
#import <Foundation/Foundation.h>
#import <Security/Security.h>
#include <stdio.h>

static int failures, checks;
#define CHECK(cond) do { checks++; if (cond) printf("PASS  %s\n", #cond); else { failures++; printf("FAIL  %s  (line %d)\n", #cond, __LINE__); } } while (0)

static CFDataRef fixture(NSString *name) {
    NSString *path = [[NSBundle mainBundle] pathForResource:name.stringByDeletingPathExtension ofType:name.pathExtension];
    return (__bridge_retained CFDataRef)[NSData dataWithContentsOfFile:path];
}
static SecCertificateRef cert(NSString *name) {
    CFDataRef d = fixture(name);
    SecCertificateRef c = d ? SecCertificateCreateWithData(NULL, d) : NULL;
    if (d) CFRelease(d);
    return c;
}
static CFIndex errorCode(CFErrorRef e) { CFIndex c = e ? CFErrorGetCode(e) : 0; if (e) CFRelease(e); return c; }

/* evaluates certs against a policy, optional anchors, at 2026-09 (inside the fixtures' validity) */
static bool evaluate(SecCertificateRef leaf, SecPolicyRef policy, SecCertificateRef anchor, CFIndex *code, CFIndex *count) {
    const void *one[] = {leaf};
    CFArrayRef certs = CFArrayCreate(NULL, one, 1, &kCFTypeArrayCallBacks);
    SecTrustRef trust = NULL;
    OSStatus s = SecTrustCreateWithCertificates(certs, policy, &trust);
    CFRelease(certs);
    if (s != errSecSuccess || !trust) return false;
    if (anchor) {
        const void *a[] = {anchor};
        CFArrayRef anchors = CFArrayCreate(NULL, a, 1, &kCFTypeArrayCallBacks);
        SecTrustSetAnchorCertificates(trust, anchors);
        CFRelease(anchors);
    }
    CFDateRef at = CFDateCreate(NULL, 1790000000 - kCFAbsoluteTimeIntervalSince1970);
    SecTrustSetVerifyDate(trust, at);
    CFRelease(at);
    CFErrorRef e = NULL;
    bool ok = SecTrustEvaluateWithError(trust, &e);
    *code = errorCode(e);
    if (count) *count = SecTrustGetCertificateCount(trust);
    CFRelease(trust);
    return ok;
}

int main(void) {
    @autoreleasepool {
        SecCertificateRef ca = cert(@"ca.der"), leaf = cert(@"leaf.der"), server = cert(@"server.der"), expired = cert(@"expired.der");
        CHECK(ca && leaf && server && expired);
        if (!ca || !leaf || !server || !expired) { printf("security c test: %d/%d passed\n", checks - failures, checks); return 1; }

        // certificates
        CFDataRef der = fixture(@"leaf.der"), copy = SecCertificateCopyData(leaf);
        CHECK(CFEqual(der, copy));
        CFRelease(der); CFRelease(copy);
        CFStringRef summary = SecCertificateCopySubjectSummary(leaf), cn = NULL;
        CHECK(summary && CFEqual(summary, CFSTR("test.isim.dev")));
        CHECK(SecCertificateCopyCommonName(ca, &cn) == errSecSuccess && cn && CFEqual(cn, CFSTR("isim Test Root CA")));
        if (summary) CFRelease(summary);
        if (cn) CFRelease(cn);
        CFDataRef serial = SecCertificateCopySerialNumberData(leaf, NULL);
        CHECK(serial && CFDataGetLength(serial) == 2 && CFDataGetBytePtr(serial)[0] == 0x12 && CFDataGetBytePtr(serial)[1] == 0x34);
        if (serial) CFRelease(serial);
        SecKeyRef key = SecCertificateCopyKey(leaf);
        CHECK(key && SecKeyGetBlockSize(key) == 256);                       // RSA 2048
        CHECK(CFGetTypeID(leaf) == SecCertificateGetTypeID() && key && CFGetTypeID(key) == SecKeyGetTypeID());
        if (key) CFRelease(key);
        CFDataRef garbage = CFDataCreate(NULL, (const UInt8 *)"nope", 4);
        CHECK(SecCertificateCreateWithData(NULL, garbage) == NULL);
        CFRelease(garbage);

        // trust: Apple's rules over the host's OpenSSL
        SecPolicyRef ssl = SecPolicyCreateSSL(true, CFSTR("test.isim.dev")), other = SecPolicyCreateSSL(true, CFSTR("other.example"));
        SecPolicyRef basic = SecPolicyCreateBasicX509();
        CHECK(CFGetTypeID(ssl) == SecPolicyGetTypeID());
        CFIndex code = 0, count = 0;
        CHECK(evaluate(server, ssl, ca, &code, &count) && code == 0 && count == 2);
        CHECK(!evaluate(server, other, ca, &code, NULL) && code == errSecHostNameMismatch);
        CHECK(!evaluate(leaf, basic, NULL, &code, NULL) && code == errSecNotTrusted);   // the test CA is not a system root
        CHECK(!evaluate(expired, basic, ca, &code, NULL) && code == errSecCertificateExpired);

        // the trust object: chain, key, the deprecated result API, exceptions
        const void *one[] = {server}, *a[] = {ca};
        CFArrayRef certs = CFArrayCreate(NULL, one, 1, &kCFTypeArrayCallBacks), anchors = CFArrayCreate(NULL, a, 1, &kCFTypeArrayCallBacks);
        SecTrustRef trust = NULL;
        CHECK(SecTrustCreateWithCertificates(certs, other, &trust) == errSecSuccess && trust && CFGetTypeID(trust) == SecTrustGetTypeID());
        SecTrustSetAnchorCertificates(trust, anchors);
        CFDateRef at = CFDateCreate(NULL, 1790000000 - kCFAbsoluteTimeIntervalSince1970);
        SecTrustSetVerifyDate(trust, at);
        SecTrustResultType result = kSecTrustResultInvalid;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        CHECK(SecTrustEvaluate(trust, &result) == errSecSuccess && result == kSecTrustResultRecoverableTrustFailure);
#pragma clang diagnostic pop
        CFDataRef exceptions = SecTrustCopyExceptions(trust);
        CHECK(exceptions && SecTrustSetExceptions(trust, exceptions));      // the user accepted this certificate
        CHECK(SecTrustEvaluateWithError(trust, NULL) && SecTrustGetTrustResult(trust, &result) == errSecSuccess && result == kSecTrustResultProceed);
        CFArrayRef chain = SecTrustCopyCertificateChain(trust);
        CHECK(chain && CFArrayGetCount(chain) == 2 && CFEqual(CFArrayGetValueAtIndex(chain, 1), ca));
        SecKeyRef tkey = SecTrustCopyKey(trust);
        CHECK(tkey != NULL);
        if (tkey) CFRelease(tkey);
        if (chain) CFRelease(chain);
        if (exceptions) CFRelease(exceptions);
        CFRelease(at); CFRelease(trust); CFRelease(certs); CFRelease(anchors);
        CFRelease(ssl); CFRelease(other); CFRelease(basic);

        // PKCS #12: a wrong passphrase, then the identity with its certificate and private key
        CFDataRef p12 = fixture(@"identity.p12");
        CFArrayRef items = NULL;
        NSDictionary *wrong = @{(__bridge id)kSecImportExportPassphrase: @"wrong"}, *right = @{(__bridge id)kSecImportExportPassphrase: @"isim"};
        CHECK(SecPKCS12Import(p12, (__bridge CFDictionaryRef)wrong, &items) == errSecAuthFailed && items == NULL);
        CHECK(SecPKCS12Import(p12, (__bridge CFDictionaryRef)right, &items) == errSecSuccess && items && CFArrayGetCount(items) == 1);
        NSDictionary *item = items && CFArrayGetCount(items) ? (__bridge NSDictionary *)CFArrayGetValueAtIndex(items, 0) : nil;
        SecIdentityRef identity = (__bridge SecIdentityRef)item[(__bridge id)kSecImportItemIdentity];
        CHECK(identity && CFGetTypeID(identity) == SecIdentityGetTypeID());
        NSArray *icChain = item[(__bridge id)kSecImportItemCertChain];
        CHECK(icChain.count >= 1 && item[(__bridge id)kSecImportItemLabel] != nil);
        SecCertificateRef idCert = NULL;
        SecKeyRef idKey = NULL;
        CHECK(identity && SecIdentityCopyCertificate(identity, &idCert) == errSecSuccess && idCert && CFEqual(idCert, leaf));
        CHECK(identity && SecIdentityCopyPrivateKey(identity, &idKey) == errSecSuccess && idKey);
        if (idCert) CFRelease(idCert);
        if (idKey) CFRelease(idKey);
        if (items) CFRelease(items);
        CFRelease(p12);
        CFRelease(ca); CFRelease(leaf); CFRelease(server); CFRelease(expired);
    }
    printf("security c test: %d/%d passed\n", checks - failures, checks);
    return failures;
}
