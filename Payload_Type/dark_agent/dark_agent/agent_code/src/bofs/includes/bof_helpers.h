#ifndef BOF_HELPERS_H
#define BOF_HELPERS_H

#include <stdlib.h>
#include <string.h>

/*
 * BOF output helpers for platform-transparent JSON building.
 *
 * The core problem on macOS AArch64: snprintf variadic calls are ABI-
 * incompatible between aarch64-linux-none (BOF compiler) and Apple's libc,
 * silently corrupting local stack variables. These helpers are non-variadic
 * and work identically on Linux and macOS.
 *
 * Usage:
 *   bof_result_t *result = bof_result_create(4096);
 *   bof_result_append(result, "{\"items\":[");
 *   // per item:
 *   if (!first) bof_result_append(result, ",");
 *   bof_result_append(result, "{");
 *   bof_field_str(result, "name", name);
 *   bof_field_int(result, "pid",  pid);
 *   bof_result_trim(result);          // strip trailing comma before }
 *   bof_result_append(result, "}");
 *   // end:
 *   bof_result_append(result, "]}");
 *   bof_result_send(result);          // sends via BeaconOutput
 *   bof_result_destroy(result);
 */

#define BOF_RESULT_GROW_SIZE 16384

/* =========================================================
 * Core shared helpers (used by both Linux and macOS paths)
 * ========================================================= */

#define INITIAL_BUFFER_SIZE 16384
#define BUFFER_GROWTH_SIZE  16384

static inline char *ensure_buf(char *buf, int *sz, int cur, int need) {
    if (cur + need >= *sz - 100) {
        int ns = *sz + BUFFER_GROWTH_SIZE;
        char *nb = (char *)realloc(buf, (size_t)ns);
        if (nb) { *sz = ns; return nb; }
    }
    return buf;
}

static inline void json_escape(char *dst, const char *src, int dsz) {
    int j = 0;
    for (int i = 0; src[i] && j < dsz - 3; i++) {
        char c = src[i];
        if      (c == '"')  { dst[j++] = '\\'; dst[j++] = '"';  }
        else if (c == '\\') { dst[j++] = '\\'; dst[j++] = '\\'; }
        else if (c == '\n') { dst[j++] = '\\'; dst[j++] = 'n';  }
        else if (c == '\r') { dst[j++] = '\\'; dst[j++] = 'r';  }
        else if (c == '\t') { dst[j++] = '\\'; dst[j++] = 't';  }
        else if ((unsigned char)c >= 32 && c <= 126) dst[j++] = c;
    }
    dst[j] = '\0';
}

/* =========================================================
 * bof_result_t is a heap-resident growable output buffer
 * All state on the heap; safe across external function calls.
 * ========================================================= */

typedef struct {
    char *data;
    int   len;
    int   cap;
} bof_result_t;

static inline bof_result_t *bof_result_create(int initial_cap) {
    bof_result_t *b = (bof_result_t *)malloc(sizeof(bof_result_t));
    if (!b) return NULL;
    b->data = (char *)malloc((size_t)initial_cap);
    if (!b->data) { free(b); return NULL; }
    b->len = 0;
    b->cap = initial_cap;
    b->data[0] = '\0';
    return b;
}

static inline void bof_result_destroy(bof_result_t *b) {
    if (b) { free(b->data); free(b); }
}

static inline void bof_result_send(bof_result_t *b) {
    if (b && b->len > 0) BeaconOutput(b->data, b->len);
}

static inline void bof_result_grow(bof_result_t *b, int needed) {
    if (!b || b->len + needed < b->cap - 4) return;
    int ns = b->cap + needed + BOF_RESULT_GROW_SIZE;
    char *nd = (char *)realloc(b->data, (size_t)ns);
    if (nd) { b->data = nd; b->cap = ns; }
}

static inline void bof_result_append(bof_result_t *b, const char *s) {
    if (!b || !s) return;
    int slen = (int)strlen(s);
    bof_result_grow(b, slen + 2);
    while (*s && b->len < b->cap - 1) b->data[b->len++] = *s++;
    b->data[b->len] = '\0';
}

static inline void bof_result_trim(bof_result_t *b) {
    if (b && b->len > 0 && b->data[b->len - 1] == ',') {
        b->data[--b->len] = '\0';
    }
}

/* Append decimal integer without snprintf */
static inline void bof_result_append_int(bof_result_t *b, int n) {
    char tmp[24]; int i = 0;
    if (n == 0) { tmp[i++] = '0'; }
    else {
        if (n < 0) { bof_result_append(b, "-"); n = -n; }
        while (n > 0) { tmp[i++] = (char)('0' + n % 10); n /= 10; }
        for (int a = 0, z = i - 1; a < z; a++, z--) {
            char t = tmp[a]; tmp[a] = tmp[z]; tmp[z] = t;
        }
    }
    tmp[i] = '\0';
    bof_result_append(b, tmp);
}

static inline void bof_result_append_uint(bof_result_t *b, unsigned int n) {
    char tmp[24]; int i = 0;
    if (n == 0) { tmp[i++] = '0'; }
    else {
        while (n > 0) { tmp[i++] = (char)('0' + n % 10); n /= 10; }
        for (int a = 0, z = i - 1; a < z; a++, z--) {
            char t = tmp[a]; tmp[a] = tmp[z]; tmp[z] = t;
        }
    }
    tmp[i] = '\0';
    bof_result_append(b, tmp);
}

static inline void bof_result_append_ull(bof_result_t *b, unsigned long long n) {
    char tmp[32]; int i = 0;
    if (n == 0) { tmp[i++] = '0'; }
    else {
        while (n > 0) { tmp[i++] = (char)('0' + (int)(n % 10)); n /= 10; }
        for (int a = 0, z = i - 1; a < z; a++, z--) {
            char t = tmp[a]; tmp[a] = tmp[z]; tmp[z] = t;
        }
    }
    tmp[i] = '\0';
    bof_result_append(b, tmp);
}

static inline void bof_result_append_hex(bof_result_t *b, unsigned int n) {
    const char *h = "0123456789abcdef";
    char tmp[12]; int i = 0;
    bof_result_append(b, "0x");
    if (n == 0) { bof_result_append(b, "0"); return; }
    while (n) { tmp[i++] = h[n & 0xF]; n >>= 4; }
    tmp[i] = '\0';
    for (int k = i - 1; k >= 0; k--) {
        char ch[2] = { tmp[k], '\0' };
        bof_result_append(b, ch);
    }
}

static inline void bof_result_append_mac(bof_result_t *b, const unsigned char *mac) {
    const char *h = "0123456789abcdef";
    for (int i = 0; i < 6; i++) {
        if (i > 0) bof_result_append(b, ":");
        char byte[3] = { h[(mac[i] >> 4) & 0xF], h[mac[i] & 0xF], '\0' };
        bof_result_append(b, byte);
    }
}

/* =========================================================
 * JSON field helpers each appending "key":value,
 * Call bof_result_trim() before closing the object with "}"
 * ========================================================= */

static inline void bof_field_str(bof_result_t *b, const char *key, const char *val) {
    bof_result_append(b, "\"");
    bof_result_append(b, key);
    bof_result_append(b, "\":\"");
    /* inline json-escape val into b */
    if (val) {
        for (; *val; val++) {
            char c = *val;
            if      (c == '"')  bof_result_append(b, "\\\"");
            else if (c == '\\') bof_result_append(b, "\\\\");
            else if (c == '\n') bof_result_append(b, "\\n");
            else if (c == '\r') bof_result_append(b, "\\r");
            else if (c == '\t') bof_result_append(b, "\\t");
            else if ((unsigned char)c >= 32 && c <= 126) {
                bof_result_grow(b, 2);
                if (b->len < b->cap - 1) b->data[b->len++] = c;
                b->data[b->len] = '\0';
            }
        }
    }
    bof_result_append(b, "\",");
}

static inline void bof_field_int(bof_result_t *b, const char *key, int val) {
    bof_result_append(b, "\"");
    bof_result_append(b, key);
    bof_result_append(b, "\":");
    bof_result_append_int(b, val);
    bof_result_append(b, ",");
}

static inline void bof_field_uint(bof_result_t *b, const char *key, unsigned int val) {
    bof_result_append(b, "\"");
    bof_result_append(b, key);
    bof_result_append(b, "\":");
    bof_result_append_uint(b, val);
    bof_result_append(b, ",");
}

static inline void bof_field_ull(bof_result_t *b, const char *key, unsigned long long val) {
    bof_result_append(b, "\"");
    bof_result_append(b, key);
    bof_result_append(b, "\":");
    bof_result_append_ull(b, val);
    bof_result_append(b, ",");
}

static inline void bof_field_hex(bof_result_t *b, const char *key, unsigned int val) {
    bof_result_append(b, "\"");
    bof_result_append(b, key);
    bof_result_append(b, "\":\"");
    bof_result_append_hex(b, val);
    bof_result_append(b, "\",");
}

#endif /* BOF_HELPERS_H */
