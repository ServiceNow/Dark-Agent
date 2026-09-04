#include "../includes/beacon.h"
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

#ifdef TARGET_MACOS

typedef void *  krb5_context;
typedef void *  krb5_ccache;
typedef void *  krb5_cccol_cursor;
typedef void *  krb5_principal;
typedef int32_t krb5_error_code;

extern krb5_error_code krb5_init_context(krb5_context *);
extern void            krb5_free_context(krb5_context);
extern krb5_error_code krb5_cccol_cursor_new(krb5_context, krb5_cccol_cursor *);
extern krb5_error_code krb5_cccol_cursor_next(krb5_context, krb5_cccol_cursor, krb5_ccache *);
extern void            krb5_cccol_cursor_free(krb5_context, krb5_cccol_cursor *);
extern krb5_error_code krb5_cc_get_principal(krb5_context, krb5_ccache, krb5_principal *);
extern const char *    krb5_cc_get_name(krb5_context, krb5_ccache);
extern const char *    krb5_cc_get_type(krb5_context, krb5_ccache);
extern krb5_error_code krb5_unparse_name(krb5_context, krb5_principal, char **);
extern void            krb5_free_unparsed_name(krb5_context, char *);
extern void            krb5_cc_close(krb5_context, krb5_ccache);
extern void            krb5_free_principal(krb5_context, krb5_principal);

void coffee(void) {
    krb5_context *ctx_buf = (krb5_context *)malloc(sizeof(krb5_context));
    if (!ctx_buf) { BeaconPrintf("error: malloc"); return; }
    *ctx_buf = NULL;

    krb5_cccol_cursor *cursor_buf = (krb5_cccol_cursor *)malloc(sizeof(krb5_cccol_cursor));
    if (!cursor_buf) { free(ctx_buf); BeaconPrintf("error: malloc"); return; }
    *cursor_buf = NULL;

    if (krb5_init_context(ctx_buf) != 0) {
        free(cursor_buf);
        free(ctx_buf);
        BeaconPrintf("error: krb5_init_context");
        return;
    }

    if (krb5_cccol_cursor_new(*ctx_buf, cursor_buf) != 0) {
        krb5_free_context(*ctx_buf);
        free(cursor_buf);
        free(ctx_buf);
        BeaconPrintf("error: krb5_cccol_cursor_new");
        return;
    }

    bof_result_t *b = bof_result_create(INITIAL_BUFFER_SIZE);
    if (!b) {
        krb5_cccol_cursor_free(*ctx_buf, cursor_buf);
        krb5_free_context(*ctx_buf);
        free(cursor_buf);
        free(ctx_buf);
        BeaconPrintf("error: malloc");
        return;
    }

    bof_result_append(b, "[");
    int first = 1;

    krb5_ccache *cache_buf = (krb5_ccache *)malloc(sizeof(krb5_ccache));
    if (!cache_buf) {
        krb5_cccol_cursor_free(*ctx_buf, cursor_buf);
        krb5_free_context(*ctx_buf);
        bof_result_destroy(b);
        free(cursor_buf);
        free(ctx_buf);
        BeaconPrintf("error: malloc");
        return;
    }

    for (;;) {
        *cache_buf = NULL;
        krb5_error_code rc = krb5_cccol_cursor_next(*ctx_buf, *cursor_buf, cache_buf);
        if (rc != 0 || *cache_buf == NULL) break;

        const char *cc_type = krb5_cc_get_type(*ctx_buf, *cache_buf);
        const char *cc_name = krb5_cc_get_name(*ctx_buf, *cache_buf);

        krb5_principal *princ_buf = (krb5_principal *)malloc(sizeof(krb5_principal));
        char **unparsed_buf = (char **)malloc(sizeof(char *));
        const char *princ_str = "";

        if (princ_buf && unparsed_buf) {
            *princ_buf = NULL;
            *unparsed_buf = NULL;
            if (krb5_cc_get_principal(*ctx_buf, *cache_buf, princ_buf) == 0 && *princ_buf) {
                if (krb5_unparse_name(*ctx_buf, *princ_buf, unparsed_buf) == 0 && *unparsed_buf) {
                    princ_str = *unparsed_buf;
                }
                krb5_free_principal(*ctx_buf, *princ_buf);
            }
        }

        if (!first) bof_result_append(b, ",");
        first = 0;

        bof_result_append(b, "{");
        bof_field_str(b, "type",      cc_type ? cc_type : "");
        bof_field_str(b, "name",      cc_name ? cc_name : "");
        bof_field_str(b, "principal", princ_str);
        bof_result_trim(b);
        bof_result_append(b, "}");

        if (unparsed_buf && *unparsed_buf) krb5_free_unparsed_name(*ctx_buf, *unparsed_buf);
        free(unparsed_buf);
        free(princ_buf);

        krb5_cc_close(*ctx_buf, *cache_buf);
    }

    bof_result_append(b, "]");

    free(cache_buf);
    krb5_cccol_cursor_free(*ctx_buf, cursor_buf);
    krb5_free_context(*ctx_buf);
    free(cursor_buf);
    free(ctx_buf);

    bof_result_send(b);
    bof_result_destroy(b);
}

#else

void coffee(void) {
    BeaconPrintf("error: krb_listccaches is macOS only");
}

#endif
