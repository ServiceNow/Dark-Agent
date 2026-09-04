#include "../includes/beacon.h"
#include <stdio.h>
#include <stdlib.h>
#include <signal.h>
#include <errno.h>
#include <string.h>
#include <unistd.h>

void coffee(int argc, char **argv) {

    // Check arguments
    if (argc < 1) {
        BeaconPrintf("Usage: kill <PID> [signal]");
        return;
    }

    // Parse PID argument
    int pid = atoi(argv[0]);

    // Parse optional signal argument (default to SIGTERM)
    int signal_num = 15; // SIGTERM
    if (argc >= 2) {
        signal_num = atoi(argv[1]);
    }

    if (pid <= 0) {
        BeaconPrintf("Error: Invalid PID: %d", pid);
        return;
    }

    // Validate signal number
    if (signal_num < 1 || signal_num > 64) {
        BeaconPrintf("Error: Invalid signal number: %d (valid range: 1-64)", signal_num);
        return;
    }

    // Check if process exists first
    if (kill(pid, 0) == -1) {
        if (errno == ESRCH) {
            BeaconPrintf("Error: Process %d does not exist", pid);
        } else if (errno == EPERM) {
            BeaconPrintf("Error: Permission denied to signal process %d", pid);
        } else {
            BeaconPrintf("Error: Failed to check process %d: %s", pid, strerror(errno));
        }
        return;
    }

    // Attempt to kill the process
    if (kill(pid, signal_num) == 0) {
        const char *signal_name = "";
        switch (signal_num) {
            case 9: signal_name = " (SIGKILL)"; break;
            case 15: signal_name = " (SIGTERM)"; break;
            case 2: signal_name = " (SIGINT)"; break;
            case 1: signal_name = " (SIGHUP)"; break;
            default: break;
        }
        BeaconPrintf("Successfully sent signal %d%s to process %d", signal_num, signal_name, pid);
    } else {
        if (errno == ESRCH) {
            BeaconPrintf("Error: Process %d no longer exists", pid);
        } else if (errno == EPERM) {
            BeaconPrintf("Error: Permission denied to kill process %d", pid);
        } else {
            BeaconPrintf("Error: Failed to kill process %d: %s", pid, strerror(errno));
        }
    }
}