#include "../includes/beacon.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define BUFFER_SIZE 8192

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
    int mib[] = {CTL_NET, PF_ROUTE, 0, AF_INET, NET_RT_FLAGS, RTF_LLINFO};
    size_t needed = 0;
    if (sysctl(mib, 6, NULL, &needed, NULL, 0) != 0 || needed == 0) {
        BeaconPrintf("Error: sysctl NET_RT_FLAGS failed");
        return;
    }

    char *buf = malloc(needed);
    if (!buf) { BeaconPrintf("Error: malloc failed"); return; }
    if (sysctl(mib, 6, buf, &needed, NULL, 0) != 0) {
        BeaconPrintf("Error: sysctl NET_RT_FLAGS read failed");
        free(buf); return;
    }

    char *ip_buf  = malloc(INET_ADDRSTRLEN);
    char *iface   = malloc(IF_NAMESIZE + 1);
    if (!ip_buf || !iface) {
        free(buf); free(ip_buf); free(iface);
        BeaconPrintf("Error: malloc"); return;
    }

    bof_result_t *b = bof_result_create(4096);
    if (!b) { free(buf); free(ip_buf); free(iface); BeaconPrintf("Error: malloc"); return; }

    bof_result_append(b, "{\"arp_entries\":[");
    int first = 1;

    char *lim = buf + needed;
    for (char *next = buf; next < lim; ) {
        struct rt_msghdr *rtm = (struct rt_msghdr *)next;
        next += rtm->rtm_msglen;

        if (rtm->rtm_type != RTM_GET) continue;

        char *addrs = (char *)(rtm + 1);
        struct sockaddr_in *dst_sa = NULL;
        struct sockaddr_dl *gw_sdl = NULL;

        for (int i = 0; i < RTAX_MAX; i++) {
            if (!(rtm->rtm_addrs & (1 << i))) continue;
            struct sockaddr *sa = (struct sockaddr *)addrs;
            if (i == RTAX_DST && sa->sa_family == AF_INET)
                dst_sa = (struct sockaddr_in *)sa;
            if (i == RTAX_GATEWAY && sa->sa_family == AF_LINK)
                gw_sdl = (struct sockaddr_dl *)sa;
            addrs += ROUNDUP(sa->sa_len);
        }

        if (!dst_sa || !gw_sdl || gw_sdl->sdl_alen == 0) continue;

        inet_ntop(AF_INET, &dst_sa->sin_addr, ip_buf, INET_ADDRSTRLEN);

        iface[0] = '\0';
        if (gw_sdl->sdl_index > 0)
            if_indextoname(gw_sdl->sdl_index, iface);

        if (!first) bof_result_append(b, ",");
        first = 0;

        bof_result_append(b, "{");
        bof_field_str(b, "ip_address", ip_buf);
        bof_result_append(b, "\"mac_address\":\"");
        bof_result_append_mac(b, (const unsigned char *)LLADDR(gw_sdl));
        bof_result_append(b, "\",");
        bof_field_hex(b, "flags", (unsigned int)rtm->rtm_flags);
        bof_field_str(b, "device", iface);
        bof_result_trim(b);
        bof_result_append(b, "}");
    }

    bof_result_append(b, "]}");
    free(buf); free(ip_buf); free(iface);
    bof_result_send(b);
    bof_result_destroy(b);
}

#else

void coffee() {
    FILE *arp_file = fopen("/proc/net/arp", "r");
    if (!arp_file) { BeaconPrintf("Error: Cannot open /proc/net/arp"); return; }

    char *out = malloc(BUFFER_SIZE);
    if (!out) { fclose(arp_file); BeaconPrintf("Error: malloc failed"); return; }
    int len = 0, first = 1;

    len += snprintf(out + len, BUFFER_SIZE - len, "{\"arp_entries\":[");

    char line[256];
    if (fgets(line, sizeof(line), arp_file)) {  /* skip header */
        while (fgets(line, sizeof(line), arp_file)) {
            char ip[64], hwtype[16], flags[16], mac[32], mask[16], dev[32];
            if (sscanf(line, "%63s %15s %15s %31s %15s %31s",
                       ip, hwtype, flags, mac, mask, dev) == 6) {
                char jip[128], jmac[64], jflags[32], jdev[64];
                json_escape(jip,    ip,    sizeof(jip));
                json_escape(jmac,   mac,   sizeof(jmac));
                json_escape(jflags, flags, sizeof(jflags));
                json_escape(jdev,   dev,   sizeof(jdev));

                if (!first) len += snprintf(out + len, BUFFER_SIZE - len, ",");
                first = 0;
                len += snprintf(out + len, BUFFER_SIZE - len,
                    "{\"ip_address\":\"%s\",\"mac_address\":\"%s\",\"flags\":\"%s\",\"device\":\"%s\"}",
                    jip, jmac, jflags, jdev);
            }
        }
    }
    len += snprintf(out + len, BUFFER_SIZE - len, "]}");
    fclose(arp_file);
    BeaconOutput(out, len);
    free(out);
}
#endif
