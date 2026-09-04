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
        BeaconPrintf("Usage: mv <source> <destination>");
        BeaconPrintf("Examples:");
        BeaconPrintf("  mv /tmp/file.txt /tmp/newname.txt");
        BeaconPrintf("  mv /home/user/doc.pdf /tmp/");
        return;
    }

    char *source      = (char *)malloc(strlen(argv[0]) + 1);
    char *destination = (char *)malloc(strlen(argv[1]) + 1);
    if (!source || !destination) {
        free(source); free(destination);
        BeaconPrintf("Error: malloc");
        return;
    }
    strcpy(source, argv[0]);
    strcpy(destination, argv[1]);

    struct stat source_stat;
    if (stat(source, &source_stat) != 0) {
        bof_result_t *result = bof_result_create(256);
        if (!result) { free(source); free(destination); BeaconPrintf("Error: malloc"); return; }
        bof_result_append(result, "{");
        bof_result_append(result, "\"success\":false,");
        bof_field_str(result, "source", source);
        bof_field_str(result, "destination", destination);
        bof_field_str(result, "error", strerror(errno));
        bof_result_trim(result);
        bof_result_append(result, "}");
        bof_result_send(result);
        bof_result_destroy(result);
        free(source); free(destination);
        return;
    }

    if (strcmp(source, "/") == 0 || strcmp(source, "/bin") == 0 ||
        strcmp(source, "/usr") == 0 || strcmp(source, "/etc") == 0 ||
        strcmp(source, "/sbin") == 0 || strcmp(source, "/lib") == 0) {
        bof_result_t *result = bof_result_create(256);
        if (!result) { free(source); free(destination); BeaconPrintf("Error: malloc"); return; }
        bof_result_append(result, "{");
        bof_result_append(result, "\"success\":false,");
        bof_field_str(result, "source", source);
        bof_field_str(result, "destination", destination);
        bof_field_str(result, "error", "System file/directory move not allowed");
        bof_result_trim(result);
        bof_result_append(result, "}");
        bof_result_send(result);
        bof_result_destroy(result);
        free(source); free(destination);
        return;
    }

    struct stat dest_stat;
    char *final_destination = NULL;
    if (stat(destination, &dest_stat) == 0 && S_ISDIR(dest_stat.st_mode)) {
        char *filename = strrchr(source, '/');
        filename = (filename == NULL) ? source : filename + 1;
        size_t fdlen = strlen(destination) + 1 + strlen(filename) + 1;
        final_destination = (char *)malloc(fdlen);
        if (!final_destination) { free(source); free(destination); BeaconPrintf("Error: malloc"); return; }
        strcpy(final_destination, destination);
        strcat(final_destination, "/");
        strcat(final_destination, filename);
    } else {
        final_destination = (char *)malloc(strlen(destination) + 1);
        if (!final_destination) { free(source); free(destination); BeaconPrintf("Error: malloc"); return; }
        strcpy(final_destination, destination);
    }

    if (stat(final_destination, &dest_stat) == 0) {
        bof_result_t *result = bof_result_create(256);
        if (!result) { free(final_destination); free(source); free(destination); BeaconPrintf("Error: malloc"); return; }
        bof_result_append(result, "{");
        bof_result_append(result, "\"success\":false,");
        bof_field_str(result, "source", source);
        bof_field_str(result, "destination", final_destination);
        bof_field_str(result, "error", "Destination already exists");
        bof_result_trim(result);
        bof_result_append(result, "}");
        bof_result_send(result);
        bof_result_destroy(result);
        free(final_destination); free(source); free(destination);
        return;
    }

    int rc = rename(source, final_destination);

    bof_result_t *result = bof_result_create(256);
    if (!result) { free(final_destination); free(source); free(destination); BeaconPrintf("Error: malloc"); return; }
    if (rc == 0) {
        const char *type = S_ISDIR(source_stat.st_mode) ? "directory" : "file";
        bof_result_append(result, "{");
        bof_result_append(result, "\"success\":true,");
        bof_field_str(result, "source", source);
        bof_field_str(result, "destination", final_destination);
        bof_field_str(result, "type", type);
        bof_field_str(result, "message", "Move completed successfully");
        bof_result_trim(result);
        bof_result_append(result, "}");
    } else {
        bof_result_append(result, "{");
        bof_result_append(result, "\"success\":false,");
        bof_field_str(result, "source", source);
        bof_field_str(result, "destination", final_destination);
        bof_field_str(result, "error", strerror(errno));
        bof_result_trim(result);
        bof_result_append(result, "}");
    }
    bof_result_send(result);
    bof_result_destroy(result);
    free(final_destination); free(source); free(destination);
}

#else

void coffee(int argc, char **argv) {
    if (argc < 2) {
        BeaconPrintf("Usage: mv <source> <destination>");
        BeaconPrintf("Examples:");
        BeaconPrintf("  mv /tmp/file.txt /tmp/newname.txt");
        BeaconPrintf("  mv /home/user/doc.pdf /tmp/");
        return;
    }
    
    char *source = argv[0];
    char *destination = argv[1];
    
    // Check if source exists
    struct stat source_stat;
    if (stat(source, &source_stat) != 0) {
        char output[1024];
        snprintf(output, sizeof(output), 
            "{\"success\":false,\"source\":\"%s\",\"destination\":\"%s\",\"error\":\"Source file does not exist: %s\"}", 
            source, destination, strerror(errno));
        BeaconOutput(output, strlen(output));
        return;
    }
    
    // Safety check: prevent moving system directories/files
    if (strcmp(source, "/") == 0 || strcmp(source, "/bin") == 0 || 
        strcmp(source, "/usr") == 0 || strcmp(source, "/etc") == 0 ||
        strcmp(source, "/sbin") == 0 || strcmp(source, "/lib") == 0) {
        char output[1024];
        snprintf(output, sizeof(output), 
            "{\"success\":false,\"source\":\"%s\",\"destination\":\"%s\",\"error\":\"System file/directory move not allowed\"}", 
            source, destination);
        BeaconOutput(output, strlen(output));
        return;
    }
    
    // Check if destination is a directory
    struct stat dest_stat;
    char final_destination[2048];
    if (stat(destination, &dest_stat) == 0 && S_ISDIR(dest_stat.st_mode)) {
        // Extract filename from source path
        char *filename = strrchr(source, '/');
        if (filename == NULL) {
            filename = source; // No path, just filename
        } else {
            filename++; // Skip the '/'
        }
        
        // Construct full destination path
        snprintf(final_destination, sizeof(final_destination), "%s/%s", destination, filename);
    } else {
        // Destination is a file path
        strncpy(final_destination, destination, sizeof(final_destination) - 1);
        final_destination[sizeof(final_destination) - 1] = '\0';
    }
    
    // Check if destination already exists
    if (stat(final_destination, &dest_stat) == 0) {
        char output[1024];
        snprintf(output, sizeof(output), 
            "{\"success\":false,\"source\":\"%s\",\"destination\":\"%s\",\"error\":\"Destination already exists\"}", 
            source, final_destination);
        BeaconOutput(output, strlen(output));
        return;
    }
    
    // Perform the move/rename
    int result = rename(source, final_destination);
    
    // Generate JSON output
    char output[2048];
    if (result == 0) {
        const char *type = S_ISDIR(source_stat.st_mode) ? "directory" : "file";
        snprintf(output, sizeof(output), 
            "{\"success\":true,\"source\":\"%s\",\"destination\":\"%s\",\"type\":\"%s\",\"message\":\"Move completed successfully\"}", 
            source, final_destination, type);
    } else {
        snprintf(output, sizeof(output), 
            "{\"success\":false,\"source\":\"%s\",\"destination\":\"%s\",\"error\":\"Failed to move: %s\"}", 
            source, final_destination, strerror(errno));
    }
    
    BeaconOutput(output, strlen(output));
}
#endif