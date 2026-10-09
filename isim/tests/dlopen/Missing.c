// libMissing.dylib: Broken.framework links it, but the app does not embed it (dlopen of Broken must fail cleanly)
int missing_value(void) { return 1; }
