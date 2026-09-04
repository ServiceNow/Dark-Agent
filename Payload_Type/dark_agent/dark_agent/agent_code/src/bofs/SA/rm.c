#include "../includes/beacon.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>
#include <errno.h>

#ifdef TARGET_MACOS

void coffee(int argc, char **argv) {
    if (argc < 1) {
        BeaconPrintf("Usage: rm <filepath>");
        return;
    }

    char *filepath = (char *)malloc(strlen(argv[0]) + 1);
    if (!filepath) { BeaconPrintf("Error: malloc"); return; }
    strcpy(filepath, argv[0]);

    struct stat file_stat;
    if (stat(filepath, &file_stat) != 0) {
        bof_result_t *result = bof_result_create(256);
        if (!result) { free(filepath); BeaconPrintf("Error: malloc"); return; }
        bof_result_append(result, "{");
        bof_result_append(result, "\"success\":false,");
        bof_field_str(result, "filepath", filepath);
        bof_field_str(result, "message", strerror(errno));
        bof_result_trim(result);
        bof_result_append(result, "}");
        bof_result_send(result);
        bof_result_destroy(result);
        free(filepath);
        return;
    }

    if (S_ISDIR(file_stat.st_mode)) {
        bof_result_t *result = bof_result_create(256);
        if (!result) { free(filepath); BeaconPrintf("Error: malloc"); return; }
        bof_result_append(result, "{");
        bof_result_append(result, "\"success\":false,");
        bof_field_str(result, "filepath", filepath);
        bof_field_str(result, "message", "Cannot remove directory. Use rmdir command instead.");
        bof_result_trim(result);
        bof_result_append(result, "}");
        bof_result_send(result);
        bof_result_destroy(result);
        free(filepath);
        return;
    }

    if (strcmp(filepath, "/") == 0 || strcmp(filepath, "/bin") == 0 ||
        strcmp(filepath, "/usr") == 0 || strcmp(filepath, "/etc") == 0) {
        bof_result_t *result = bof_result_create(256);
        if (!result) { free(filepath); BeaconPrintf("Error: malloc"); return; }
        bof_result_append(result, "{");
        bof_result_append(result, "\"success\":false,");
        bof_field_str(result, "filepath", filepath);
        bof_field_str(result, "message", "System file removal not allowed");
        bof_result_trim(result);
        bof_result_append(result, "}");
        bof_result_send(result);
        bof_result_destroy(result);
        free(filepath);
        return;
    }

    int rc = unlink(filepath);

    bof_result_t *result = bof_result_create(256);
    if (!result) { free(filepath); BeaconPrintf("Error: malloc"); return; }
    if (rc == 0) {
        bof_result_append(result, "{");
        bof_result_append(result, "\"success\":true,");
        bof_field_str(result, "filepath", filepath);
        bof_field_str(result, "message", "File removed successfully");
        bof_result_trim(result);
        bof_result_append(result, "}");
    } else {
        bof_result_append(result, "{");
        bof_result_append(result, "\"success\":false,");
        bof_field_str(result, "filepath", filepath);
        bof_field_str(result, "message", strerror(errno));
        bof_result_trim(result);
        bof_result_append(result, "}");
    }
    bof_result_send(result);
    bof_result_destroy(result);
    free(filepath);
}

#else

void coffee(int argc, char **argv) {
    if (argc < 1) {
        BeaconPrintf("Usage: rm <filepath>");
        return;
    }
    
    char *filepath = argv[0];
    
    // Check if file exists
    struct stat file_stat;
    if (stat(filepath, &file_stat) != 0) {
        char output[512];
        snprintf(output, sizeof(output), 
            "{\"success\":false,\"filepath\":\"%s\",\"message\":\"File does not exist: %s\"}", 
            filepath, strerror(errno));
        BeaconOutput(output, strlen(output));
        return;
    }
    
    // Reject directories - use rmdir BOF instead
    if (S_ISDIR(file_stat.st_mode)) {
        char output[512];
        snprintf(output, sizeof(output), 
            "{\"success\":false,\"filepath\":\"%s\",\"message\":\"Cannot remove directory. Use rmdir command instead.\"}", 
            filepath);
        BeaconOutput(output, strlen(output));
        return;
    }
    
    // Safety check: prevent removal of system files
    if (strcmp(filepath, "/") == 0 || strcmp(filepath, "/bin") == 0 || 
        strcmp(filepath, "/usr") == 0 || strcmp(filepath, "/etc") == 0) {
        char output[512];
        snprintf(output, sizeof(output), 
            "{\"success\":false,\"filepath\":\"%s\",\"message\":\"System file removal not allowed\"}", 
            filepath);
        BeaconOutput(output, strlen(output));
        return;
    }
    
    // Remove the file
    int result = unlink(filepath);
    
    // Generate JSON output
    char output[1024];
    if (result == 0) {
        snprintf(output, sizeof(output), 
            "{\"success\":true,\"filepath\":\"%s\",\"type\":\"file\",\"message\":\"File removed successfully\"}", 
            filepath);
    } else {
        snprintf(output, sizeof(output), 
            "{\"success\":false,\"filepath\":\"%s\",\"type\":\"file\",\"message\":\"Failed to remove file: %s\"}", 
            filepath, strerror(errno));
    }
    
    BeaconOutput(output, strlen(output));
}
#endif