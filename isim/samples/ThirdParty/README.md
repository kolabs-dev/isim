# Third-party samples

Apps that use real third-party SDKs, from their own packages, to show how they run on isim. isim does not
re-implement third-party libraries (AGENTS.md, "Only Apple's SDK"). When one of these does not build or run, the cause
is an iOS API isim lacks: fix it in isim, or record it on its framework page (docs/frameworks/) and in a `coverage` issue.

They are not part of `isim/build.py`: they need the network (`isim build` fetches the packages, and the SDKs talk to
their own servers). Build one with `isim build`:

```bash
isim build -project samples/ThirdParty/GoogleAds/GoogleAds.xcodeproj -o /tmp/ga
isim run /tmp/ga/GoogleAds.app
```

| Sample | SDK | Status |
|---|---|---|
| GoogleAds | Google Mobile Ads 13 (`swift-package-manager-google-mobile-ads`): banner and interstitial with Google's test ad units | builds and runs: the SDK starts, the test banner and interstitial load from Google's servers and show ([#200](https://github.com/kolabs-dev/isim/issues/200)). Known gap: tapping the interstitial's close button does not dismiss it yet. `ISIM_OBJC_AUDIT=1` lists the selectors the SDK references that isim does not implement (most are optional delegate callbacks). Google Mobile Ads 12.14 also links (#606: CFNetwork's CFHost, Darwin's per-header force-load markers, the status bar orientation notifications) and runs: its test banner and interstitial load too (#609: nested `pthread_once` no longer deadlocks) |
