// isim Network for C and Objective-C: the globals behind Apple's macros (NW_PARAMETERS_DEFAULT_CONFIGURATION,
// NW_PARAMETERS_DISABLE_PROTOCOL, NW_CONNECTION_SEND_IDEMPOTENT_CONTENT, NW_CONNECTION_*_CONTEXT). The C API itself is
// CAPI.swift; it recognises these blocks by address. The content contexts are made by the Swift side when the library
// loads.
#include <CoreFoundation/CoreFoundation.h>
#include <Block.h>

#define EXPORT __attribute__((used, visibility("default")))

typedef void (^nw_configure_block_t)(void *options);
typedef void (^nw_send_completion_t)(void *error);

EXPORT const nw_configure_block_t _nw_parameters_configure_protocol_default_configuration = ^(void *options) { (void)options; };
EXPORT const nw_configure_block_t _nw_parameters_configure_protocol_disable = ^(void *options) { (void)options; };
EXPORT const nw_send_completion_t _nw_connection_send_idempotent_content = ^(void *error) { (void)error; };

EXPORT const CFStringRef kNWErrorDomainPOSIX = CFSTR("kNWErrorDomainPOSIX");
EXPORT const CFStringRef kNWErrorDomainDNS = CFSTR("kNWErrorDomainDNS");
EXPORT const CFStringRef kNWErrorDomainTLS = CFSTR("kNWErrorDomainTLS");

EXPORT void *_nw_content_context_default_message;
EXPORT void *_nw_content_context_final_send;
EXPORT void *_nw_content_context_default_stream;

// for CAPI.swift
const void *_isim_nw_block(int which) {
    switch (which) {
    case 0: return (const void *)_nw_parameters_configure_protocol_default_configuration;
    case 1: return (const void *)_nw_parameters_configure_protocol_disable;
    default: return (const void *)_nw_connection_send_idempotent_content;
    }
}
const void *_isim_nw_block_copy(const void *block) { return _Block_copy(block); }
void _isim_nw_block_release(const void *block) { _Block_release(block); }
void *_isim_nw_context(int which);
void *_isim_nw_context_global(int which) {
    return which == 0 ? _nw_content_context_default_message : which == 1 ? _nw_content_context_final_send : _nw_content_context_default_stream;
}                     /* CAPI.swift: a retained nw_content_context_t */

__attribute__((constructor)) static void make_contexts(void) {
    _nw_content_context_default_message = _isim_nw_context(0);
    _nw_content_context_final_send = _isim_nw_context(1);
    _nw_content_context_default_stream = _isim_nw_context(2);
}
