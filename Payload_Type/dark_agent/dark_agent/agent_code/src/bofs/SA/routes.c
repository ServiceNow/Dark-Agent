#include "../includes/beacon.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef TARGET_MACOS
#include <sys/sysctl.h>
#include <net/route.h>
#include <net/if_dl.h>
#include <netinet/in.h>
#include <arpa/inet.h>

#define ROUNDUP(a) ((a) > 0 ? (1 + (((a) - 1) | (sizeof(long) - 1))) : sizeof(long))
#define IF_NAMESIZE 16
extern char *if_indextoname(unsigned int ifindex, char *ifname);

void coffee() {
    int mib[] = {CTL_NET, PF_ROUTE, 0, AF_INET, NET_RT_DUMP, 0};
    size_t needed = 0;
    if (sysctl(mib, 6, NULL, &needed, NULL, 0) != 0 || needed == 0) {
        BeaconPrintf("Error: sysctl NET_RT_DUMP failed");
        return;
    }

    char *buf = malloc(needed);
    if (!buf) { BeaconPrintf("Error: malloc failed"); return; }
    if (sysctl(mib, 6, buf, &needed, NULL, 0) != 0) {
        BeaconPrintf("Error: sysctl NET_RT_DUMP read failed");
        free(buf);
        return;
    }

    char *dst_h   = malloc(INET_ADDRSTRLEN);
    char *gw_h    = malloc(INET_ADDRSTRLEN);
    char *nm_h    = malloc(INET_ADDRSTRLEN);
    char *iface_h = malloc(IF_NAMESIZE + 1);
    if (!dst_h || !gw_h || !nm_h || !iface_h) {
        free(buf); free(dst_h); free(gw_h); free(nm_h); free(iface_h);
        BeaconPrintf("Error: malloc"); return;
    }

    bof_result_t *b = bof_result_create(INITIAL_BUFFER_SIZE);
    if (!b) {
        free(buf); free(dst_h); free(gw_h); free(nm_h); free(iface_h);
        BeaconPrintf("Error: malloc"); return;
    }

    bof_result_append(b, "{\"routes\":[");
    int first = 1;

    char *lim = buf + needed;
    for (char *next = buf; next < lim; ) {
        struct rt_msghdr *rtm = (struct rt_msghdr *)next;
        next += rtm->rtm_msglen;

        if (rtm->rtm_type != RTM_GET && rtm->rtm_type != RTM_ADD) continue;

        char *addrs = (char *)(rtm + 1);
        struct sockaddr_in *dst_sa = NULL, *gw_sa = NULL, *nm_sa = NULL;

        for (int i = 0; i < RTAX_MAX; i++) {
            if (!(rtm->rtm_addrs & (1 << i))) continue;
            struct sockaddr *sa = (struct sockaddr *)addrs;
            if (i == RTAX_DST     && sa->sa_family == AF_INET) dst_sa = (struct sockaddr_in*)sa;
            if (i == RTAX_GATEWAY && sa->sa_family == AF_INET) gw_sa  = (struct sockaddr_in*)sa;
            if (i == RTAX_NETMASK && sa->sa_family == AF_INET) nm_sa  = (struct sockaddr_in*)sa;
            addrs += sa->sa_len > 0 ? ROUNDUP(sa->sa_len) : sizeof(long);
        }

        if (!dst_sa) continue;

        inet_ntop(AF_INET, &dst_sa->sin_addr, dst_h, INET_ADDRSTRLEN);
        gw_h[0] = '\0';
        if (gw_sa) inet_ntop(AF_INET, &gw_sa->sin_addr, gw_h, INET_ADDRSTRLEN);
        if (nm_sa) inet_ntop(AF_INET, &nm_sa->sin_addr, nm_h, INET_ADDRSTRLEN);
        else { nm_h[0]='0'; nm_h[1]='.'; nm_h[2]='0'; nm_h[3]='.';
               nm_h[4]='0'; nm_h[5]='.'; nm_h[6]='0'; nm_h[7]='\0'; }

        iface_h[0] = '\0';
        if (rtm->rtm_index > 0) if_indextoname(rtm->rtm_index, iface_h);

        int cidr = 0;
        if (nm_sa) {
            unsigned int m = ntohl(nm_sa->sin_addr.s_addr);
            while (m & 0x80000000) { cidr++; m <<= 1; }
        }

        if (!first) bof_result_append(b, ",");
        first = 0;

        bof_result_append(b, "{");
        bof_field_str (b, "interface",   iface_h);
        bof_field_str (b, "destination", dst_h);
        bof_field_str (b, "gateway",     gw_h);
        bof_field_str (b, "netmask",     nm_h);
        bof_field_int (b, "cidr",        cidr);
        bof_field_uint(b, "flags",       (unsigned int)rtm->rtm_flags);
        bof_field_uint(b, "metric",      (unsigned int)rtm->rtm_rmx.rmx_hopcount);
        bof_field_str (b, "type",        dst_sa->sin_addr.s_addr == 0 ? "default" : "unicast");
        bof_result_trim(b);
        bof_result_append(b, "}");
    }

    bof_result_append(b, "]}");
    free(buf); free(dst_h); free(gw_h); free(nm_h); free(iface_h);
    bof_result_send(b);
    bof_result_destroy(b);
}

#else

static void hex_to_ip(unsigned int hex_ip, char* ip_str) {
    sprintf(ip_str, "%d.%d.%d.%d",
            hex_ip & 0xFF, (hex_ip >> 8) & 0xFF,
            (hex_ip >> 16) & 0xFF, (hex_ip >> 24) & 0xFF);
}

#define ROUTES_BUF_SIZE 8192

void coffee() {
    FILE *rf = fopen("/proc/net/route", "r");
    if (!rf) { BeaconPrintf("Error: Cannot open /proc/net/route"); return; }

    char *out = malloc(ROUTES_BUF_SIZE);
    if (!out) { fclose(rf); BeaconPrintf("Error: malloc failed"); return; }
    int len = 0, first = 1;

    len += snprintf(out + len, ROUTES_BUF_SIZE - len, "{\"routes\":[");

    char line[256];
    if (fgets(line, sizeof(line), rf)) {  /* skip header */
        while (fgets(line, sizeof(line), rf)) {
            char iface[32];
            unsigned int dst, gw, flags, refcnt, use, metric, mask, mtu, win, irtt;
            if (sscanf(line, "%31s %x %x %x %x %x %x %x %x %x %x",
                       iface, &dst, &gw, &flags, &refcnt, &use,
                       &metric, &mask, &mtu, &win, &irtt) < 8) continue;

            char dst_ip[16], gw_ip[16], nm_ip[16];
            hex_to_ip(dst,  dst_ip);
            hex_to_ip(gw,   gw_ip);
            hex_to_ip(mask, nm_ip);

            int cidr = 0;
            for (unsigned int m = mask; m; m >>= 1) cidr += (m & 1);

            const char *rtype = (dst == 0) ? "default" :
                                ((dst & 0xE0) == 0xE0) ? "multicast" : "unicast";

            char jiface[64];
            json_escape(jiface, iface, sizeof(jiface));

            if (!first) len += snprintf(out + len, ROUTES_BUF_SIZE - len, ",");
            first = 0;
            len += snprintf(out + len, ROUTES_BUF_SIZE - len,
                "{\"interface\":\"%s\",\"destination\":\"%s\",\"gateway\":\"%s\","
                "\"netmask\":\"%s\",\"cidr\":%d,\"flags\":%u,\"metric\":%u,\"type\":\"%s\"}",
                jiface, dst_ip, gw_ip, nm_ip, cidr, flags, metric, rtype);
        }
    }
    len += snprintf(out + len, ROUTES_BUF_SIZE - len, "]}");
    fclose(rf);
    BeaconOutput(out, len);
    free(out);
}
#endif
