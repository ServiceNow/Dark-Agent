#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <ifaddrs.h>
#include <netinet/in.h>
#include <sys/types.h>
#include <errno.h>
#include "../includes/beacon.h"

#ifdef TARGET_MACOS
/* AF_LINK = 18 on macOS/BSD — link-layer addresses, IFF_* flags */
#define SA_FAMILY_LINK 18
#define IFF_UP        0x1
#define IFF_BROADCAST 0x2

void coffee() {
    struct ifaddrs *ifap = NULL;
    if (getifaddrs(&ifap) != 0) {
        BeaconPrintf("Failed to get interface addresses");
        return;
    }

    /* heap-allocate seen[] — 16KB on the stack overflows the BOF thread */
    char (*seen)[64] = malloc(256 * 64);
    int seen_count = 0;
    if (!seen) { freeifaddrs(ifap); BeaconPrintf("Error: malloc"); return; }

    char *ipv4  = malloc(INET_ADDRSTRLEN), *nm_s = malloc(INET_ADDRSTRLEN);
    char *bc_s  = malloc(INET_ADDRSTRLEN), *ip6  = malloc(INET6_ADDRSTRLEN);
    if (!ipv4 || !nm_s || !bc_s || !ip6) {
        free(seen); free(ipv4); free(nm_s); free(bc_s); free(ip6);
        freeifaddrs(ifap); BeaconPrintf("Error: malloc"); return;
    }

    bof_result_t *b = bof_result_create(INITIAL_BUFFER_SIZE);
    if (!b) {
        free(seen); free(ipv4); free(nm_s); free(bc_s); free(ip6);
        freeifaddrs(ifap); BeaconPrintf("Error: malloc"); return;
    }

    bof_result_append(b, "{\"interfaces\":[");
    int first_iface = 1;

    for (struct ifaddrs *ifa = ifap; ifa; ifa = ifa->ifa_next) {
        if (!ifa->ifa_addr || ifa->ifa_addr->sa_family != SA_FAMILY_LINK) continue;

        int dup = 0;
        for (int i = 0; i < seen_count; i++) {
            if (strcmp(seen[i], ifa->ifa_name) == 0) { dup = 1; break; }
        }
        if (dup || seen_count >= 256) continue;
        strncpy(seen[seen_count++], ifa->ifa_name, 63);

        if (!first_iface) bof_result_append(b, ",");
        first_iface = 0;

        bof_result_append(b, "{");
        bof_field_str(b, "name",   ifa->ifa_name);
        bof_field_str(b, "status", (ifa->ifa_flags & IFF_UP) ? "up" : "down");
        bof_result_trim(b);
        bof_result_append(b, ",\"ipv4_addresses\":[");

        int first_v4 = 1;
        for (struct ifaddrs *a = ifap; a; a = a->ifa_next) {
            if (!a->ifa_addr || strcmp(a->ifa_name, ifa->ifa_name) != 0) continue;
            if (a->ifa_addr->sa_family != AF_INET) continue;

            struct sockaddr_in *sin  = (struct sockaddr_in*)a->ifa_addr;
            struct sockaddr_in *snm  = a->ifa_netmask ? (struct sockaddr_in*)a->ifa_netmask : NULL;
            struct sockaddr_in *sbrd = (a->ifa_flags & IFF_BROADCAST && a->ifa_broadaddr)
                                       ? (struct sockaddr_in*)a->ifa_broadaddr : NULL;

            inet_ntop(AF_INET, &sin->sin_addr, ipv4, INET_ADDRSTRLEN);
            nm_s[0] = '\0';
            bc_s[0] = '\0';
            if (snm)  inet_ntop(AF_INET, &snm->sin_addr,  nm_s, INET_ADDRSTRLEN);
            if (sbrd) inet_ntop(AF_INET, &sbrd->sin_addr, bc_s, INET_ADDRSTRLEN);

            if (!first_v4) bof_result_append(b, ",");
            first_v4 = 0;

            bof_result_append(b, "{");
            bof_field_str(b, "address",   ipv4);
            bof_field_str(b, "netmask",   nm_s);
            bof_field_str(b, "broadcast", bc_s);
            bof_result_trim(b);
            bof_result_append(b, "}");
        }

        bof_result_append(b, "],\"ipv6_addresses\":[");

        int first_v6 = 1;
        for (struct ifaddrs *a = ifap; a; a = a->ifa_next) {
            if (!a->ifa_addr || strcmp(a->ifa_name, ifa->ifa_name) != 0) continue;
            if (a->ifa_addr->sa_family != AF_INET6) continue;

            struct sockaddr_in6 *s6 = (struct sockaddr_in6*)a->ifa_addr;
            inet_ntop(AF_INET6, &s6->sin6_addr, ip6, INET6_ADDRSTRLEN);

            if (!first_v6) bof_result_append(b, ",");
            first_v6 = 0;

            bof_result_append(b, "{");
            bof_field_str(b, "address", ip6);
            bof_result_trim(b);
            bof_result_append(b, "}");
        }

        bof_result_append(b, "]}");
    }

    bof_result_append(b, "]}");
    free(seen); free(ipv4); free(nm_s); free(bc_s); free(ip6);
    freeifaddrs(ifap);
    bof_result_send(b);
    bof_result_destroy(b);
}

#else
#include <net/if.h>
#include <linux/if_packet.h>
#define SA_FAMILY_LINK AF_PACKET

#define BUFFER_SIZE 16384

void coffee() {
    struct ifaddrs *ifap = NULL;
    if (getifaddrs(&ifap) != 0) {
        BeaconPrintf("Failed to get interface addresses: %s", strerror(errno));
        return;
    }

    char *out = malloc(BUFFER_SIZE);
    if (!out) { freeifaddrs(ifap); BeaconPrintf("Error: malloc failed"); return; }
    int len = 0, first_iface = 1;

    len += snprintf(out + len, BUFFER_SIZE - len, "{\"interfaces\":[");

    char seen[256][64];
    int seen_count = 0;

    for (struct ifaddrs *ifa = ifap; ifa; ifa = ifa->ifa_next) {
        if (!ifa->ifa_addr || ifa->ifa_addr->sa_family != SA_FAMILY_LINK) continue;

        int dup = 0;
        for (int i = 0; i < seen_count; i++) {
            if (strcmp(seen[i], ifa->ifa_name) == 0) { dup = 1; break; }
        }
        if (dup || seen_count >= 256) continue;
        strncpy(seen[seen_count++], ifa->ifa_name, 63);

        char jname[128];
        json_escape(jname, ifa->ifa_name, sizeof(jname));

        if (!first_iface) len += snprintf(out + len, BUFFER_SIZE - len, ",");
        first_iface = 0;

        len += snprintf(out + len, BUFFER_SIZE - len,
            "{\"name\":\"%s\",\"status\":\"%s\",\"ipv4_addresses\":[",
            jname, (ifa->ifa_flags & IFF_UP) ? "up" : "down");

        int first_v4 = 1;
        for (struct ifaddrs *a = ifap; a; a = a->ifa_next) {
            if (!a->ifa_addr || strcmp(a->ifa_name, ifa->ifa_name) != 0) continue;
            if (a->ifa_addr->sa_family != AF_INET) continue;

            struct sockaddr_in *sin  = (struct sockaddr_in*)a->ifa_addr;
            struct sockaddr_in *snm  = a->ifa_netmask ? (struct sockaddr_in*)a->ifa_netmask : NULL;
            struct sockaddr_in *sbrd = (a->ifa_flags & IFF_BROADCAST && a->ifa_broadaddr)
                                       ? (struct sockaddr_in*)a->ifa_broadaddr : NULL;

            char ipv4[INET_ADDRSTRLEN], nm[INET_ADDRSTRLEN] = "", bc[INET_ADDRSTRLEN] = "";
            inet_ntop(AF_INET, &sin->sin_addr, ipv4, sizeof(ipv4));
            if (snm)  inet_ntop(AF_INET, &snm->sin_addr,  nm, sizeof(nm));
            if (sbrd) inet_ntop(AF_INET, &sbrd->sin_addr, bc, sizeof(bc));

            if (!first_v4) len += snprintf(out + len, BUFFER_SIZE - len, ",");
            first_v4 = 0;
            len += snprintf(out + len, BUFFER_SIZE - len,
                "{\"address\":\"%s\",\"netmask\":\"%s\",\"broadcast\":\"%s\"}", ipv4, nm, bc);
        }

        len += snprintf(out + len, BUFFER_SIZE - len, "],\"ipv6_addresses\":[");

        int first_v6 = 1;
        for (struct ifaddrs *a = ifap; a; a = a->ifa_next) {
            if (!a->ifa_addr || strcmp(a->ifa_name, ifa->ifa_name) != 0) continue;
            if (a->ifa_addr->sa_family != AF_INET6) continue;

            struct sockaddr_in6 *s6 = (struct sockaddr_in6*)a->ifa_addr;
            char ip6[INET6_ADDRSTRLEN];
            inet_ntop(AF_INET6, &s6->sin6_addr, ip6, sizeof(ip6));

            if (!first_v6) len += snprintf(out + len, BUFFER_SIZE - len, ",");
            first_v6 = 0;
            len += snprintf(out + len, BUFFER_SIZE - len, "{\"address\":\"%s\"}", ip6);
        }

        len += snprintf(out + len, BUFFER_SIZE - len, "]}");
    }

    len += snprintf(out + len, BUFFER_SIZE - len, "]}");
    freeifaddrs(ifap);
    BeaconOutput(out, len);
    free(out);
}
#endif
