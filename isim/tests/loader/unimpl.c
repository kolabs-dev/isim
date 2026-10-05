/* Imports a function isim does not implement: the loader binds it to a named trap. */
int puts(const char *); int isim_test_unimplemented(void);
int main(void) { puts("before unimplemented call"); return isim_test_unimplemented(); }
