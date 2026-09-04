#include "../includes/beacon.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <arpa/inet.h>

#define NETSTAT_BUF_SIZE  65536
#define NETSTAT_GUARD     (NETSTAT_BUF_SIZE - 256)

typedef struct { char proto[8]; char addr[64]; int port; char state[16]; } conn_t;

static int cmp_port(const void *a, const void *b) {
    return ((conn_t*)a)->port - ((conn_t*)b)->port;
}

#ifdef TARGET_MACOS

void coffee() {
    BeaconPrintf("netstat: not supported on macOS");
}

#else

void coffee() {
    conn_t *listening   = malloc(200 * sizeof(conn_t));
    conn_t *established = malloc(200 * sizeof(conn_t));
    if (!listening || !established) {
        free(listening); free(established);
        BeaconPrintf("Error: malloc failed");
        return;
    }
    int lc = 0, ec = 0;

    /* TCP */
    FILE *tf = fopen("/proc/net/tcp", "r");
    if (!tf) { BeaconPrintf("Error: Cannot open /proc/net/tcp"); return; }

    char line[512];
    if (fgets(line, sizeof(line), tf)) {
        while (fgets(line, sizeof(line), tf) && lc < 200 && ec < 200) {
            int a, b, c, d, lport, rport, state;
            if (sscanf(line, "%*d: %02x%02x%02x%02x:%x %02x%02x%02x%02x:%x %x",
                       &a,&b,&c,&d,&lport, &a,&b,&c,&d,&rport, &state) == 11) {
                conn_t *cur = NULL;
                if (state == 10) { cur = &listening[lc++];    strcpy(cur->state, "LISTEN"); }
                else if (state == 1) { cur = &established[ec++]; strcpy(cur->state, "ESTABLISHED"); }
                if (cur) {
                    strcpy(cur->proto, "tcp");
                    cur->port = lport;
                    snprintf(cur->addr, sizeof(cur->addr), "%d.%d.%d.%d", d,c,b,a);
                }
            }
        }
    }
    fclose(tf);

    /* UDP */
    FILE *uf = fopen("/proc/net/udp", "r");
    if (uf) {
        if (fgets(line, sizeof(line), uf)) {
            while (fgets(line, sizeof(line), uf) && lc < 200) {
                int a, b, c, d, lport;
                if (sscanf(line, "%*d: %02x%02x%02x%02x:%x", &a,&b,&c,&d,&lport) == 5) {
                    conn_t *cur = &listening[lc++];
                    strcpy(cur->proto, "udp");
                    cur->port = lport;
                    snprintf(cur->addr, sizeof(cur->addr), "%d.%d.%d.%d", d,c,b,a);
                    strcpy(cur->state, "LISTEN");
                }
            }
        }
        fclose(uf);
    }

    qsort(listening,   lc, sizeof(conn_t), cmp_port);
    qsort(established, ec, sizeof(conn_t), cmp_port);

    char *out = malloc(NETSTAT_BUF_SIZE);
    if (!out) { BeaconPrintf("Error: malloc failed"); return; }
    int len = 0, first = 1;

    len += snprintf(out + len, NETSTAT_BUF_SIZE - len, "{\"connections\":[");
    for (int i = 0; i < lc && len < NETSTAT_GUARD; i++) {
        char jp[16], ja[128], js[32];
        json_escape(jp, listening[i].proto, sizeof(jp));
        json_escape(ja, listening[i].addr,  sizeof(ja));
        json_escape(js, listening[i].state, sizeof(js));
        if (!first) len += snprintf(out + len, NETSTAT_BUF_SIZE - len, ",");
        first = 0;
        len += snprintf(out + len, NETSTAT_BUF_SIZE - len,
            "{\"protocol\":\"%s\",\"local_address\":\"%s\",\"local_port\":%d,\"state\":\"%s\"}",
            jp, ja, listening[i].port, js);
    }
    for (int i = 0; i < ec && len < NETSTAT_GUARD; i++) {
        char jp[16], ja[128], js[32];
        json_escape(jp, established[i].proto, sizeof(jp));
        json_escape(ja, established[i].addr,  sizeof(ja));
        json_escape(js, established[i].state, sizeof(js));
        if (!first) len += snprintf(out + len, NETSTAT_BUF_SIZE - len, ",");
        first = 0;
        len += snprintf(out + len, NETSTAT_BUF_SIZE - len,
            "{\"protocol\":\"%s\",\"local_address\":\"%s\",\"local_port\":%d,\"state\":\"%s\"}",
            jp, ja, established[i].port, js);
    }
    len += snprintf(out + len, NETSTAT_BUF_SIZE - len, "]}");
    BeaconOutput(out, len);
    free(out);
    free(listening);
    free(established);
}
#endif
