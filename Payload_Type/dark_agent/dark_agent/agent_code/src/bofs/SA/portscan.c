#include "../includes/beacon.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <fcntl.h>
#include <errno.h>

// Simple port scan function to check if ports are open or closed
void coffee(int argc, char* argv[]) {
    // Print argument information for testing

    for (int i = 0; i < argc; i++) {
        // Directly print the value without format specifiers
        char buffer[1024];
        snprintf(buffer, sizeof(buffer), "Arg[%d]: %s", i, argv[i] ? argv[i] : "<NULL>");
    }

    // Make sure we're passing 2 args.  The last field is a null term for C arrays
    if (argc < 3) {
        BeaconPrintf("Usage: portscan <host> <port1,port2,...>");
        return;
    }

    char* host = argv[0];
    char* ports_str = argv[1];

    // Parse comma-separated ports
    char* port_token = strtok(ports_str, ",");

    BeaconPrintf("Scanning host %s", host);

    while (port_token != NULL) {
        int port = atoi(port_token);
        if (port <= 0 || port > 65535) {
            BeaconPrintf("Invalid port: %s", port_token);
            port_token = strtok(NULL, ",");
            continue;
        }

        // Create socket
        int sock = socket(AF_INET, SOCK_STREAM, 0);
        if (sock < 0) {
            BeaconPrintf("Socket creation failed");
            return;
        }
        // Set non-blocking
        int flags = fcntl(sock, F_GETFL, 0);
        fcntl(sock, F_SETFL, flags | O_NONBLOCK);

        // Set up address structure
        struct sockaddr_in addr;
        memset(&addr, 0, sizeof(addr));
        addr.sin_family = AF_INET;
        addr.sin_addr.s_addr = inet_addr(host);
        addr.sin_port = htons(port);

        // Connect with timeout
        int result = connect(sock, (struct sockaddr *)&addr, sizeof(addr));

        if (result < 0 && errno == EINPROGRESS) {
            // Wait for connection with timeout
            fd_set fdset;
            struct timeval tv;

            FD_ZERO(&fdset);
            FD_SET(sock, &fdset);
            tv.tv_sec = 5;  // 5 second timeout
            tv.tv_usec = 0;

            int select_result = select(sock + 1, NULL, &fdset, NULL, &tv);

            if (select_result == 1) {
                int so_error;
                socklen_t len = sizeof(so_error);
                getsockopt(sock, SOL_SOCKET, SO_ERROR, &so_error, &len);

                if (so_error == 0) {
                    BeaconPrintf("Port %d: OPEN", port);
                } else {
                    BeaconPrintf("Port %d: CLOSED", port);
                }
            } else {
                BeaconPrintf("Port %d: CLOSED (timeout)", port);
            }
        } else if (result == 0) {
            BeaconPrintf("Port %d: OPEN", port);
        } else {
            BeaconPrintf("Port %d: CLOSED", port);
        }

        close(sock);
        port_token = strtok(NULL, ",");
    }
}