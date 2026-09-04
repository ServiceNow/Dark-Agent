#include "../includes/beacon.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>
#include <errno.h>

#ifdef TARGET_MACOS

void coffee(int argc, char **argv) {
    if (argc < 2) {
        BeaconPrintf("Usage: chmod <mode> <filepath>");
        BeaconPrintf("Examples:");
        BeaconPrintf("  chmod 755 /tmp/file");
        BeaconPrintf("  chmod 644 /home/user/document.txt");
        return;
    }

    char *mode_str = (char *)malloc(strlen(argv[0]) + 1);
    char *filepath = (char *)malloc(strlen(argv[1]) + 1);
    if (!mode_str || !filepath) {
        free(mode_str); free(filepath);
        BeaconPrintf("Error: malloc");
        return;
    }
    strcpy(mode_str, argv[0]);
    strcpy(filepath, argv[1]);

    char *endptr;
    long mode_long = strtol(mode_str, &endptr, 8);

    if (*endptr != '\0' || mode_long < 0 || mode_long > 07777) {
        bof_result_t *result = bof_result_create(256);
        if (!result) { free(mode_str); free(filepath); BeaconPrintf("Error: malloc"); return; }
        bof_result_append(result, "{");
        bof_result_append(result, "\"success\":false,");
        bof_field_str(result, "error", "Invalid mode. Mode must be octal (e.g., 755, 644)");
        bof_result_trim(result);
        bof_result_append(result, "}");
        bof_result_send(result);
        bof_result_destroy(result);
        free(mode_str); free(filepath);
        return;
    }

    mode_t mode = (mode_t)mode_long;

    struct stat file_stat;
    if (stat(filepath, &file_stat) != 0) {
        bof_result_t *result = bof_result_create(256);
        if (!result) { free(mode_str); free(filepath); BeaconPrintf("Error: malloc"); return; }
        bof_result_append(result, "{");
        bof_result_append(result, "\"success\":false,");
        bof_field_str(result, "filepath", filepath);
        bof_field_str(result, "error", strerror(errno));
        bof_result_trim(result);
        bof_result_append(result, "}");
        bof_result_send(result);
        bof_result_destroy(result);
        free(mode_str); free(filepath);
        return;
    }

    if (chmod(filepath, mode) != 0) {
        bof_result_t *result = bof_result_create(256);
        if (!result) { free(mode_str); free(filepath); BeaconPrintf("Error: malloc"); return; }
        bof_result_append(result, "{");
        bof_result_append(result, "\"success\":false,");
        bof_field_str(result, "filepath", filepath);
        bof_field_str(result, "error", strerror(errno));
        bof_result_trim(result);
        bof_result_append(result, "}");
        bof_result_send(result);
        bof_result_destroy(result);
        free(mode_str); free(filepath);
        return;
    }

    bof_result_t *result = bof_result_create(256);
    if (!result) { free(mode_str); free(filepath); BeaconPrintf("Error: malloc"); return; }
    bof_result_append(result, "{");
    bof_result_append(result, "\"success\":true,");
    bof_field_str(result, "filepath", filepath);
    bof_field_str(result, "message", "Permissions changed successfully");
    bof_result_trim(result);
    bof_result_append(result, "}");
    bof_result_send(result);
    bof_result_destroy(result);
    free(mode_str); free(filepath);
}

#else

void coffee(int argc, char **argv) {
    if (argc < 2) {
        BeaconPrintf("Usage: chmod <mode> <filepath>");
        BeaconPrintf("Examples:");
        BeaconPrintf("  chmod 755 /tmp/file");
        BeaconPrintf("  chmod 644 /home/user/document.txt");
        return;
    }

    char *mode_str = argv[0];
    char *filepath = argv[1];
    
    // Convert mode string to octal
    char *endptr;
    long mode_long = strtol(mode_str, &endptr, 8);
    
    // Validate mode conversion
    if (*endptr != '\0' || mode_long < 0 || mode_long > 07777) {
        char output[1024];
        snprintf(output, sizeof(output), 
            "{\"success\":false,\"error\":\"Invalid mode '%s'. Mode must be octal (e.g., 755, 644)\"}", 
            mode_str);
        BeaconOutput(output, strlen(output));
        return;
    }
    
    mode_t mode = (mode_t)mode_long;
    
    // Check if file exists
    struct stat file_stat;
    if (stat(filepath, &file_stat) != 0) {
        char output[1024];
        snprintf(output, sizeof(output), 
            "{\"success\":false,\"filepath\":\"%s\",\"error\":\"File does not exist or cannot be accessed: %s\"}", 
            filepath, strerror(errno));
        BeaconOutput(output, strlen(output));
        return;
    }
    
    // Get current permissions for comparison
    mode_t old_mode = file_stat.st_mode & 07777;
    
    // Change file permissions
    if (chmod(filepath, mode) != 0) {
        char output[1024];
        snprintf(output, sizeof(output), 
            "{\"success\":false,\"filepath\":\"%s\",\"error\":\"Failed to change permissions: %s\"}", 
            filepath, strerror(errno));
        BeaconOutput(output, strlen(output));
        return;
    }
    
    // Format output as JSON
    char output[1024];
    snprintf(output, sizeof(output), 
        "{\"success\":true,\"filepath\":\"%s\",\"old_mode\":\"%04o\",\"new_mode\":\"%04o\",\"message\":\"Permissions changed successfully\"}", 
        filepath, old_mode, mode);
    
    BeaconOutput(output, strlen(output));
}
#endif