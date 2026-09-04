#include "../includes/beacon.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <netdb.h>
#include <arpa/inet.h>
#include <resolv.h>
#include <unistd.h>
#include <sys/time.h>

/* Simple DNS query function */
int dns_query(const char* hostname, const char* nameserver, char ipv4_addrs[][16], char ipv6_addrs[][40], int* ipv4_count, int* ipv6_count) {
    *ipv4_count = 0;
    *ipv6_count = 0;

    unsigned char query[512];
    int query_len = 0;

    /* DNS header */
    query[query_len++] = 0x12; query[query_len++] = 0x34;
    query[query_len++] = 0x01; query[query_len++] = 0x00;
    query[query_len++] = 0x00; query[query_len++] = 0x01;
    query[query_len++] = 0x00; query[query_len++] = 0x00;
    query[query_len++] = 0x00; query[query_len++] = 0x00;
    query[query_len++] = 0x00; query[query_len++] = 0x00;

    /* Question section - encode hostname */
    const char* ptr = hostname;
    while (*ptr) {
        const char* dot = strchr(ptr, '.');
        int label_len = dot ? (dot - ptr) : strlen(ptr);

        if (label_len > 63) return -1;

        query[query_len++] = label_len;
        memcpy(query + query_len, ptr, label_len);
        query_len += label_len;

        if (dot) {
            ptr = dot + 1;
        } else {
            break;
        }
    }
    query[query_len++] = 0x00;
    query[query_len++] = 0x00; query[query_len++] = 0x01;
    query[query_len++] = 0x00; query[query_len++] = 0x01;

    int sock = socket(AF_INET, SOCK_DGRAM, 0);
    if (sock < 0) return -1;

    struct timeval timeout;
    timeout.tv_sec = 5;
    timeout.tv_usec = 0;
    setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));

    struct sockaddr_in ns_addr;
    memset(&ns_addr, 0, sizeof(ns_addr));
    ns_addr.sin_family = AF_INET;
    ns_addr.sin_port = htons(53);
    inet_pton(AF_INET, nameserver, &ns_addr.sin_addr);

    if (sendto(sock, query, query_len, 0, (struct sockaddr*)&ns_addr, sizeof(ns_addr)) < 0) {
        close(sock);
        return -1;
    }

    unsigned char response[512];
    int response_len = recvfrom(sock, response, sizeof(response), 0, NULL, NULL);
    close(sock);

    if (response_len < 12) return -1;

    int questions = (response[4] << 8) | response[5];
    int answers = (response[6] << 8) | response[7];

    if (answers == 0) return -1;

    int offset = 12;
    for (int i = 0; i < questions; i++) {
        while (offset < response_len && response[offset] != 0) {
            if ((response[offset] & 0xC0) == 0xC0) {
                offset += 2;
                break;
            }
            offset += response[offset] + 1;
        }
        if (response[offset] == 0) offset++;
        offset += 4;
    }

    for (int i = 0; i < answers && offset < response_len; i++) {
        if ((response[offset] & 0xC0) == 0xC0) {
            offset += 2;
        } else {
            while (offset < response_len && response[offset] != 0) {
                offset += response[offset] + 1;
            }
            offset++;
        }

        if (offset + 10 > response_len) break;

        int type = (response[offset] << 8) | response[offset + 1];
        int data_len = (response[offset + 8] << 8) | response[offset + 9];
        offset += 10;

        if (type == 1 && data_len == 4 && *ipv4_count < 10) {
            struct in_addr addr;
            memcpy(&addr, response + offset, 4);
            strcpy(ipv4_addrs[*ipv4_count], inet_ntoa(addr));
            (*ipv4_count)++;
        } else if (type == 28 && data_len == 16 && *ipv6_count < 10) {
            char ipv6_str[40];
            inet_ntop(AF_INET6, response + offset, ipv6_str, sizeof(ipv6_str));
            strcpy(ipv6_addrs[*ipv6_count], ipv6_str);
            (*ipv6_count)++;
        }

        offset += data_len;
    }

    return (*ipv4_count > 0 || *ipv6_count > 0) ? 0 : -1;
}

#ifdef TARGET_MACOS

static const char *macos_get_nameserver(char *buf, int bufsz) {
    FILE *f = fopen("/etc/resolv.conf", "r");
    if (!f) { strncpy(buf, "8.8.8.8", bufsz - 1); return buf; }
    char line[256];
    while (fgets(line, sizeof(line), f)) {
        if (strncmp(line, "nameserver", 10) == 0) {
            char *ns = line + 10;
            while (*ns == ' ' || *ns == '\t') ns++;
            char *end = ns;
            while (*end && *end != '\n' && *end != ' ' && *end != '\r') end++;
            *end = '\0';
            if (*ns) { strncpy(buf, ns, bufsz - 1); fclose(f); return buf; }
        }
    }
    fclose(f);
    strncpy(buf, "8.8.8.8", bufsz - 1);
    return buf;
}

void coffee(int argc, char **argv) {
    if (argc < 1) { BeaconPrintf("Usage: nslookup <hostname1>,<hostname2> [nameserver]"); return; }

    char ns_buf[64] = "";
    const char *nameserver = (argc >= 2 && argv[1] && argv[1][0]) ? argv[1]
                                                                   : macos_get_nameserver(ns_buf, sizeof(ns_buf));

    char *hostnames_copy = malloc(strlen(argv[0]) + 1);
    if (!hostnames_copy) { BeaconPrintf("Error: malloc"); return; }
    strcpy(hostnames_copy, argv[0]);

    bof_result_t *result = bof_result_create(INITIAL_BUFFER_SIZE);
    if (!result) { free(hostnames_copy); BeaconPrintf("Error: malloc"); return; }

    bof_result_append(result, "{\"nameserver\":\"");
    bof_result_append(result, nameserver);
    bof_result_append(result, "\",\"lookups\":[");
    int first = 1;

    char *token = strtok(hostnames_copy, ",");
    while (token != NULL) {
        char ipv4_addrs[10][16];
        char ipv6_addrs[10][40];
        int ipv4_count = 0, ipv6_count = 0;
        int status = dns_query(token, nameserver, ipv4_addrs, ipv6_addrs, &ipv4_count, &ipv6_count);

        if (!first) bof_result_append(result, ",");
        first = 0;

        bof_result_append(result, "{");
        bof_field_str(result, "hostname", token);

        bof_result_append(result, "\"ipv4_addresses\":[");
        for (int i = 0; i < ipv4_count; i++) {
            if (i > 0) bof_result_append(result, ",");
            bof_result_append(result, "\"");
            bof_result_append(result, ipv4_addrs[i]);
            bof_result_append(result, "\"");
        }
        bof_result_append(result, "],\"ipv6_addresses\":[");
        for (int i = 0; i < ipv6_count; i++) {
            if (i > 0) bof_result_append(result, ",");
            bof_result_append(result, "\"");
            bof_result_append(result, ipv6_addrs[i]);
            bof_result_append(result, "\"");
        }
        bof_result_append(result, "],");
        bof_field_str(result, "status", status == 0 ? "success" : "failed");
        bof_result_trim(result);
        bof_result_append(result, "}");

        token = strtok(NULL, ",");
    }

    bof_result_append(result, "]}");
    free(hostnames_copy);
    bof_result_send(result);
    bof_result_destroy(result);
}

#else

void coffee(int argc, char **argv) {
    if (argc < 1) {
        BeaconPrintf("Usage: nslookup <hostname1>,<hostname2> [nameserver]");
        return;
    }

    char *hostnames = argv[0];
    char *nameserver = NULL;

    if (argc >= 2) {
        nameserver = argv[1];
    }

    char *hostnames_copy = malloc(strlen(hostnames) + 1);
    strcpy(hostnames_copy, hostnames);

    char *output;
    int total_len = 0;
    int buffer_size = INITIAL_BUFFER_SIZE;

    output = malloc(buffer_size);
    if (output == NULL) {
        BeaconPrintf("Error: Unable to allocate memory for output buffer");
        free(hostnames_copy);
        return;
    }

    if (nameserver) {
        total_len += snprintf(output + total_len, buffer_size - total_len, "{\"nameserver\":\"%s\",\"lookups\":[", nameserver);
    } else {
        total_len += snprintf(output + total_len, buffer_size - total_len, "{\"nameserver\":\"system\",\"lookups\":[");
    }
    int first_lookup = 1;

    char *token = strtok(hostnames_copy, ",");

    while (token != NULL) {
        struct addrinfo hints, *result;
        memset(&hints, 0, sizeof(hints));
        hints.ai_family = AF_UNSPEC;
        hints.ai_socktype = SOCK_STREAM;

        int status;
        char ipv4_addrs[10][16];
        char ipv6_addrs[10][40];
        int ipv4_count = 0, ipv6_count = 0;

        if (nameserver) {
            struct sockaddr_in ns_addr;
            if (inet_pton(AF_INET, nameserver, &ns_addr.sin_addr) <= 0) {
                status = -1;
            } else {
                status = dns_query(token, nameserver, ipv4_addrs, ipv6_addrs, &ipv4_count, &ipv6_count);
            }
        } else {
            status = getaddrinfo(token, NULL, &hints, &result);
        }

        char json_hostname[256];
        json_escape(json_hostname, token, sizeof(json_hostname));

        output = ensure_buf(output, &buffer_size, total_len, 1000);

        if (!first_lookup) {
            total_len += snprintf(output + total_len, buffer_size - total_len, ",");
        }
        first_lookup = 0;

        total_len += snprintf(output + total_len, buffer_size - total_len, "{\"hostname\":\"%s\",\"ipv4_addresses\":[", json_hostname);

        if (status == 0) {
            if (nameserver) {
                for (int i = 0; i < ipv4_count; i++) {
                    if (i > 0) {
                        total_len += snprintf(output + total_len, buffer_size - total_len, ",");
                    }
                    total_len += snprintf(output + total_len, buffer_size - total_len, "\"%s\"", ipv4_addrs[i]);
                }

                total_len += snprintf(output + total_len, buffer_size - total_len, "],\"ipv6_addresses\":[");

                for (int i = 0; i < ipv6_count; i++) {
                    if (i > 0) {
                        total_len += snprintf(output + total_len, buffer_size - total_len, ",");
                    }
                    total_len += snprintf(output + total_len, buffer_size - total_len, "\"%s\"", ipv6_addrs[i]);
                }
            } else {
                struct addrinfo *p;
                int first_ipv4 = 1;

                for (p = result; p != NULL; p = p->ai_next) {
                    if (p->ai_family == AF_INET) {
                        struct sockaddr_in *ipv4 = (struct sockaddr_in *)p->ai_addr;
                        char ipstr[INET_ADDRSTRLEN];
                        inet_ntop(AF_INET, &(ipv4->sin_addr), ipstr, INET_ADDRSTRLEN);

                        if (!first_ipv4) {
                            total_len += snprintf(output + total_len, buffer_size - total_len, ",");
                        }
                        first_ipv4 = 0;
                        total_len += snprintf(output + total_len, buffer_size - total_len, "\"%s\"", ipstr);
                    }
                }

                total_len += snprintf(output + total_len, buffer_size - total_len, "],\"ipv6_addresses\":[");

                int first_ipv6 = 1;
                for (p = result; p != NULL; p = p->ai_next) {
                    if (p->ai_family == AF_INET6) {
                        struct sockaddr_in6 *ipv6 = (struct sockaddr_in6 *)p->ai_addr;
                        char ipstr[INET6_ADDRSTRLEN];
                        inet_ntop(AF_INET6, &(ipv6->sin6_addr), ipstr, INET6_ADDRSTRLEN);

                        if (!first_ipv6) {
                            total_len += snprintf(output + total_len, buffer_size - total_len, ",");
                        }
                        first_ipv6 = 0;
                        total_len += snprintf(output + total_len, buffer_size - total_len, "\"%s\"", ipstr);
                    }
                }

                freeaddrinfo(result);
            }

            total_len += snprintf(output + total_len, buffer_size - total_len, "],\"status\":\"success\"}");
        } else {
            total_len += snprintf(output + total_len, buffer_size - total_len, "],\"ipv6_addresses\":[],\"status\":\"failed\"}");
        }

        token = strtok(NULL, ",");
    }

    total_len += snprintf(output + total_len, buffer_size - total_len, "]}");

    free(hostnames_copy);
    BeaconOutput(output, total_len);
    free(output);
}
#endif
