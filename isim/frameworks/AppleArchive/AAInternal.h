/* isim AppleArchive: internal helpers shared by its files. */
#pragma once
#include <AppleArchive/AppleArchive.h>

int aa_write_all(AAByteStream s, const void *buf, size_t n);
ssize_t aa_read_all(AAByteStream s, void *buf, size_t n);
/* a key from 3 characters, and back ("TYP") */
AAFieldKey aa_key(const char *s);
int aa_key_is(AAFieldKey k, const char *s);
/* parses an encoded header whose first 6 bytes ("AA01" + its size) are `head`; reads the rest from s */
AAHeader aa_header_read(AAByteStream s, int *eof);
/* the size of a hash function's value (0: unknown) */
size_t aa_hash_size(AAHashFunction f);
/* computes a hash of a whole file (the DAT of `path`) */
int aa_hash_file(int fd, AAHashFunction f, uint8_t *out);
