/* isim Foundation (ARC): the constants of the URL loading system for Objective-C (the classes are Foundation's Swift
 * overlay classes: SwiftClasses.m, swift/overlays/Foundation/ObjCNetworking.swift); the same strings as the overlay's */
#import <Foundation/Foundation.h>

NSString *const NSURLErrorDomain = @"NSURLErrorDomain";
NSString *const NSURLErrorFailingURLErrorKey = @"NSErrorFailingURLKey";
NSString *const NSURLErrorFailingURLStringErrorKey = @"NSErrorFailingURLStringKey";
NSString *const NSErrorFailingURLStringKey = @"NSErrorFailingURLStringKey";
NSString *const NSURLErrorFailingURLPeerTrustErrorKey = @"NSURLErrorFailingURLPeerTrustErrorKey";
NSString *const NSURLErrorBackgroundTaskCancelledReasonKey = @"NSURLErrorBackgroundTaskCancelledReasonKey";

NSHTTPCookiePropertyKey const NSHTTPCookieName = @"Name", NSHTTPCookieValue = @"Value", NSHTTPCookieOriginURL = @"OriginURL",
    NSHTTPCookieVersion = @"Version", NSHTTPCookieDomain = @"Domain", NSHTTPCookiePath = @"Path", NSHTTPCookieSecure = @"Secure",
    NSHTTPCookieExpires = @"Expires", NSHTTPCookieComment = @"Comment", NSHTTPCookieCommentURL = @"CommentURL",
    NSHTTPCookieDiscard = @"Discard", NSHTTPCookieMaximumAge = @"Max-Age", NSHTTPCookiePort = @"Port",
    NSHTTPCookieSameSitePolicy = @"SameSite";
NSHTTPCookieStringPolicy const NSHTTPCookieSameSiteLax = @"lax", NSHTTPCookieSameSiteStrict = @"strict";
NSString *const NSHTTPCookieManagerAcceptPolicyChangedNotification = @"NSHTTPCookieManagerAcceptPolicyChangedNotification";
NSString *const NSHTTPCookieManagerCookiesChangedNotification = @"NSHTTPCookieManagerCookiesChangedNotification";

NSString *const NSURLProtectionSpaceHTTP = @"http", *const NSURLProtectionSpaceHTTPS = @"https", *const NSURLProtectionSpaceFTP = @"ftp",
    *const NSURLProtectionSpaceHTTPProxy = @"http", *const NSURLProtectionSpaceHTTPSProxy = @"https",
    *const NSURLProtectionSpaceFTPProxy = @"ftp", *const NSURLProtectionSpaceSOCKSProxy = @"SOCKS";
NSString *const NSURLAuthenticationMethodDefault = @"NSURLAuthenticationMethodDefault",
    *const NSURLAuthenticationMethodHTTPBasic = @"NSURLAuthenticationMethodHTTPBasic",
    *const NSURLAuthenticationMethodHTTPDigest = @"NSURLAuthenticationMethodHTTPDigest",
    *const NSURLAuthenticationMethodHTMLForm = @"NSURLAuthenticationMethodHTMLForm",
    *const NSURLAuthenticationMethodNTLM = @"NSURLAuthenticationMethodNTLM",
    *const NSURLAuthenticationMethodNegotiate = @"NSURLAuthenticationMethodNegotiate",
    *const NSURLAuthenticationMethodClientCertificate = @"NSURLAuthenticationMethodClientCertificate",
    *const NSURLAuthenticationMethodServerTrust = @"NSURLAuthenticationMethodServerTrust";
NSString *const NSURLCredentialStorageChangedNotification = @"NSURLCredentialStorageChangedNotification";

const int64_t NSURLSessionTransferSizeUnknown = -1;
const float NSURLSessionTaskPriorityDefault = 0.5f, NSURLSessionTaskPriorityLow = 0.25f, NSURLSessionTaskPriorityHigh = 0.75f;
NSString *const NSURLSessionDownloadTaskResumeData = @"NSURLSessionDownloadTaskResumeData";
