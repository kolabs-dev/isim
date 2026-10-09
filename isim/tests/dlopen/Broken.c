// Broken.framework: depends on @rpath/libMissing.dylib, which is not in the app
int missing_value(void);
int broken_value(void) { return missing_value(); }
