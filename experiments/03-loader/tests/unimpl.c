int puts(const char *); int getpid(void);
int main(void) { puts("before unimplemented call"); return getpid() > 0 ? 0 : 1; }
