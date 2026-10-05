/* Self-declared prototypes: no SDK headers. Darwin x86-64 uses the SysV ABI. */
typedef unsigned long size_t;
typedef struct _opaque_pthread_t *pthread_t;           /* Darwin: pointer */
typedef struct { long sig; char opaque[56]; } pthread_mutex_t; /* Darwin layout: 64 bytes */
#define PTHREAD_MUTEX_INITIALIZER {0x32AAABA7, {0}}      /* Darwin _PTHREAD_MUTEX_SIG_init */
int puts(const char *);
int printf(const char *, ...);
void *malloc(size_t);
void free(void *);
size_t strlen(const char *);
int pthread_create(pthread_t *, const void *, void *(*)(void *), void *);
int pthread_join(pthread_t, void **);
int pthread_mutex_lock(pthread_mutex_t *);
int pthread_mutex_unlock(pthread_mutex_t *);

static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
static long counter;

static void *worker(void *arg) {
    for (int i = 0; i < 100000; i++) {
        pthread_mutex_lock(&lock); counter++; pthread_mutex_unlock(&lock);
    }
    return arg;
}

int main(int argc, char **argv) {
    puts("hello from an iOS-simulator Mach-O");
    printf("argc=%d argv[0]=%s\n", argc, argv[0]);
    char *p = malloc(64);
    for (int i = 0; i < 63; i++) p[i] = 'a' + i % 26;
    p[63] = 0;
    printf("malloc ok, strlen=%zu\n", strlen(p));
    free(p);
    pthread_t t[4];
    for (int i = 0; i < 4; i++) pthread_create(&t[i], 0, worker, 0);
    for (int i = 0; i < 4; i++) pthread_join(t[i], 0);
    printf("threads ok, counter=%ld (expect 400000)\n", counter);
    return counter == 400000 ? 42 : 1;
}
