# Third-party samples

Apps that use real third-party SDKs, from their own packages, to show how they run on isim. isim does not
re-implement third-party libraries (AGENTS.md, "Only Apple's SDK"). When one of these does not build or run, the cause
is an iOS API isim lacks: fix it in isim, or record it in docs/COVERAGE.md and an issue.

They are not part of `isim/build.py`: they need the network (`isim build` fetches the packages, and the SDKs talk to
their own servers). Build one with `isim build`:

```bash
isim build -project samples/ThirdParty/GoogleAds/GoogleAds.xcodeproj -o /tmp/ga
isim run /tmp/ga/GoogleAds.app
```

| Sample | SDK | Status |
|---|---|---|
| GoogleAds | Google Mobile Ads 13 (`swift-package-manager-google-mobile-ads`): banner and interstitial with Google's test ad units | does not build yet: the SDK's headers import `WebKit/WebKit.h`, and isim's WebKit has no Objective-C interface ([#200](https://github.com/kolabs-dev/isim/issues/200)) |
