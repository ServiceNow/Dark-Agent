#include "../includes/beacon.h"
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

#ifdef TARGET_MACOS

typedef void *  krb5_context;
typedef void *  krb5_ccache;
typedef void *  krb5_principal;
typedef void *  krb5_cc_cursor;
typedef int32_t krb5_error_code;

/*
 * krb5_creds layout (Heimdal, macOS arm64) used via raw byte offsets:
 *   +0  void*    client  (principal)
 *   +8  void*    server  (principal)
 *   +40 int32_t  authtime
 *   +44 int32_t  starttime
 *   +48 int32_t  endtime
 * 256 bytes is a safe allocation for the full struct.
 */
#define KRB5_CREDS_BUF_SIZE 256
#define CREDS_OFF_CLIENT    0
#define CREDS_OFF_SERVER    8
#define CREDS_OFF_ENDTIME   48

extern krb5_error_code krb5_init_context(krb5_context *);
extern void            krb5_free_context(krb5_context);
extern krb5_error_code krb5_cc_default(krb5_context, krb5_ccache *);
extern krb5_error_code krb5_cc_resolve(krb5_context, const char *, krb5_ccache *);
extern krb5_error_code krb5_cc_get_principal(krb5_context, krb5_ccache, krb5_principal *);
extern const char *    krb5_cc_get_type(krb5_context, krb5_ccache);
extern const char *    krb5_cc_get_name(krb5_context, krb5_ccache);
extern krb5_error_code krb5_cc_start_seq_get(krb5_context, krb5_ccache, krb5_cc_cursor *);
extern krb5_error_code krb5_cc_next_cred(krb5_context, krb5_ccache, krb5_cc_cursor *, void *);
extern krb5_error_code krb5_cc_end_seq_get(krb5_context, krb5_ccache, krb5_cc_cursor *);
extern void            krb5_free_cred_contents(krb5_context, void *);
extern krb5_error_code krb5_unparse_name(krb5_context, krb5_principal, char **);
extern void            krb5_free_unparsed_name(krb5_context, char *);
extern void            krb5_cc_close(krb5_context, krb5_ccache);
extern void            krb5_free_principal(krb5_context, krb5_principal);

void coffee(int argc, char **argv) {
    krb5_context *ctx_buf = (krb5_context *)malloc(sizeof(krb5_context));
    if (!ctx_buf) { BeaconPrintf("error: malloc"); return; }
    *ctx_buf = NULL;

    if (krb5_init_context(ctx_buf) != 0) {
        free(ctx_buf);
        BeaconPrintf("error: krb5_init_context");
        return;
    }

    krb5_ccache *cache_buf = (krb5_ccache *)malloc(sizeof(krb5_ccache));
    if (!cache_buf) {
        krb5_free_context(*ctx_buf);
        free(ctx_buf);
        BeaconPrintf("error: malloc");
        return;
    }
    *cache_buf = NULL;

    if (argc < 1 || !argv[0] || argv[0][0] == '\0') {
        krb5_free_context(*ctx_buf);
        free(cache_buf);
        free(ctx_buf);
        BeaconPrintf("usage: krb_dump_kirbi <ccache> -- run krb_listccaches to enumerate cache names");
        return;
    }

    char *cc_name = (char *)malloc(strlen(argv[0]) + 1);
    if (!cc_name) {
        krb5_free_context(*ctx_buf);
        free(cache_buf);
        free(ctx_buf);
        BeaconPrintf("error: malloc");
        return;
    }
    strcpy(cc_name, argv[0]);
    if (krb5_cc_resolve(*ctx_buf, cc_name, cache_buf) != 0) {
        free(cc_name);
        krb5_free_context(*ctx_buf);
        free(cache_buf);
        free(ctx_buf);
        BeaconPrintf("error: krb5_cc_resolve");
        return;
    }
    free(cc_name);

    /* Resolve the display name: "type:name" */
    char *cc_label = NULL;
    {
        const char *cc_type = krb5_cc_get_type(*ctx_buf, *cache_buf);
        const char *cc_name = krb5_cc_get_name(*ctx_buf, *cache_buf);
        int type_len = cc_type ? (int)strlen(cc_type) : 0;
        int name_len = cc_name ? (int)strlen(cc_name) : 0;
        cc_label = (char *)malloc((size_t)(type_len + 1 + name_len + 1));
        if (cc_label) {
            if (type_len) {
                memcpy(cc_label, cc_type, (size_t)type_len);
                cc_label[type_len] = ':';
                if (name_len) memcpy(cc_label + type_len + 1, cc_name, (size_t)name_len);
                cc_label[type_len + 1 + name_len] = '\0';
            } else {
                if (name_len) memcpy(cc_label, cc_name, (size_t)name_len);
                cc_label[name_len] = '\0';
            }
        }
    }

    bof_result_t *b = bof_result_create(INITIAL_BUFFER_SIZE);
    if (!b) {
        free(cc_label);
        krb5_cc_close(*ctx_buf, *cache_buf);
        krb5_free_context(*ctx_buf);
        free(cache_buf);
        free(ctx_buf);
        BeaconPrintf("error: malloc");
        return;
    }

    bof_result_append(b, "{");
    bof_field_str(b, "ccache", cc_label ? cc_label : "");
    bof_result_trim(b);
    bof_result_append(b, ",\"credentials\":[");
    free(cc_label);

    krb5_cc_cursor *cursor_buf = (krb5_cc_cursor *)malloc(sizeof(krb5_cc_cursor));
    if (!cursor_buf) {
        bof_result_destroy(b);
        krb5_cc_close(*ctx_buf, *cache_buf);
        krb5_free_context(*ctx_buf);
        free(cache_buf);
        free(ctx_buf);
        BeaconPrintf("error: malloc");
        return;
    }
    *cursor_buf = NULL;

    if (krb5_cc_start_seq_get(*ctx_buf, *cache_buf, cursor_buf) != 0) {
        free(cursor_buf);
        bof_result_append(b, "]}");
        bof_result_send(b);
        bof_result_destroy(b);
        krb5_cc_close(*ctx_buf, *cache_buf);
        krb5_free_context(*ctx_buf);
        free(cache_buf);
        free(ctx_buf);
        return;
    }

    uint8_t *creds_buf = (uint8_t *)malloc(KRB5_CREDS_BUF_SIZE);
    if (!creds_buf) {
        krb5_cc_end_seq_get(*ctx_buf, *cache_buf, cursor_buf);
        free(cursor_buf);
        bof_result_append(b, "]}");
        bof_result_send(b);
        bof_result_destroy(b);
        krb5_cc_close(*ctx_buf, *cache_buf);
        krb5_free_context(*ctx_buf);
        free(cache_buf);
        free(ctx_buf);
        BeaconPrintf("error: malloc");
        return;
    }

    int first = 1;

    for (;;) {
        memset(creds_buf, 0, KRB5_CREDS_BUF_SIZE);
        krb5_error_code rc = krb5_cc_next_cred(*ctx_buf, *cache_buf, cursor_buf, creds_buf);
        if (rc != 0) break;

        char **client_str_buf = (char **)malloc(sizeof(char *));
        char **server_str_buf = (char **)malloc(sizeof(char *));
        const char *client_str = "";
        const char *server_str = "";

        if (client_str_buf) {
            *client_str_buf = NULL;
            if (krb5_unparse_name(*ctx_buf, *(void **)(creds_buf + CREDS_OFF_CLIENT), client_str_buf) == 0
                    && *client_str_buf) {
                client_str = *client_str_buf;
            }
        }
        if (server_str_buf) {
            *server_str_buf = NULL;
            if (krb5_unparse_name(*ctx_buf, *(void **)(creds_buf + CREDS_OFF_SERVER), server_str_buf) == 0
                    && *server_str_buf) {
                server_str = *server_str_buf;
            }
        }

        if (!first) bof_result_append(b, ",");
        first = 0;

        bof_result_append(b, "{");
        bof_field_str(b, "client", client_str);
        bof_field_str(b, "server", server_str);
        bof_field_int(b, "endtime", (int)*(int32_t *)(creds_buf + CREDS_OFF_ENDTIME));
        bof_result_trim(b);
        bof_result_append(b, "}");

        if (client_str_buf && *client_str_buf) krb5_free_unparsed_name(*ctx_buf, *client_str_buf);
        if (server_str_buf && *server_str_buf) krb5_free_unparsed_name(*ctx_buf, *server_str_buf);
        free(client_str_buf);
        free(server_str_buf);

        krb5_free_cred_contents(*ctx_buf, creds_buf);
    }

    free(creds_buf);
    krb5_cc_end_seq_get(*ctx_buf, *cache_buf, cursor_buf);
    free(cursor_buf);

    bof_result_append(b, "]}");

    krb5_cc_close(*ctx_buf, *cache_buf);
    krb5_free_context(*ctx_buf);
    free(cache_buf);
    free(ctx_buf);

    bof_result_send(b);
    bof_result_destroy(b);
}

#else

void coffee(int argc, char **argv) {
    (void)argc; (void)argv;
    BeaconPrintf("error: krb_dump_kirbi is macOS only");
}

#endif
