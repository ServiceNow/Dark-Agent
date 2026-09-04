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
        BeaconPrintf("Usage: mkdir <directory>");
        BeaconPrintf("Examples:");
        BeaconPrintf("  mkdir /tmp/newdir");
        BeaconPrintf("  mkdir /tmp/path/to/newdir");
        return;
    }

    char *directory = (char *)malloc(strlen(argv[0]) + 1);
    if (!directory) { BeaconPrintf("Error: malloc"); return; }
    strcpy(directory, argv[0]);

    mode_t mode = S_IRWXU | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH;

    bof_result_t *result = bof_result_create(512);
    if (!result) { free(directory); BeaconPrintf("Error: malloc"); return; }

    struct stat dir_stat;
    if (stat(directory, &dir_stat) == 0) {
        if (S_ISDIR(dir_stat.st_mode)) {
            bof_result_append(result, "{");
            bof_result_append(result, "\"success\":true,");
            bof_field_str(result, "directory", directory);
            bof_field_str(result, "message", "Directory already exists");
            bof_result_trim(result);
            bof_result_append(result, "}");
            bof_result_send(result);
            bof_result_destroy(result);
            free(directory);
            return;
        } else {
            bof_result_append(result, "{");
            bof_result_append(result, "\"success\":false,");
            bof_field_str(result, "directory", directory);
            bof_field_str(result, "error", "File exists but is not a directory");
            bof_result_trim(result);
            bof_result_append(result, "}");
            bof_result_send(result);
            bof_result_destroy(result);
            free(directory);
            return;
        }
    }

    char *path_copy = strdup(directory);
    if (!path_copy) {
        bof_result_append(result, "{");
        bof_result_append(result, "\"success\":false,");
        bof_field_str(result, "directory", directory);
        bof_field_str(result, "error", "malloc failed");
        bof_result_trim(result);
        bof_result_append(result, "}");
        bof_result_send(result);
        bof_result_destroy(result);
        free(directory);
        return;
    }

    char *current_path = path_copy;
    if (*current_path == '/') current_path++;

    char *slash;
    while ((slash = strchr(current_path, '/')) != NULL) {
        *slash = '\0';

        char *partial_path = (char *)malloc(strlen(directory) + 2);
        if (!partial_path) {
            free(path_copy);
            bof_result_append(result, "{");
            bof_result_append(result, "\"success\":false,");
            bof_field_str(result, "directory", directory);
            bof_field_str(result, "error", "malloc failed");
            bof_result_trim(result);
            bof_result_append(result, "}");
            bof_result_send(result);
            bof_result_destroy(result);
            free(directory);
            return;
        }
        if (directory[0] == '/') {
            partial_path[0] = '/';
            strcpy(partial_path + 1, path_copy);
        } else {
            strcpy(partial_path, path_copy);
        }

        if (stat(partial_path, &dir_stat) != 0) {
            if (mkdir(partial_path, mode) != 0 && errno != EEXIST) {
                char *errmsg = (char *)malloc(strlen("Failed to create parent directory '") +
                                              strlen(partial_path) + strlen("': ") +
                                              strlen(strerror(errno)) + 2);
                if (errmsg) {
                    strcpy(errmsg, "Failed to create parent directory '");
                    strcat(errmsg, partial_path);
                    strcat(errmsg, "': ");
                    strcat(errmsg, strerror(errno));
                }
                bof_result_append(result, "{");
                bof_result_append(result, "\"success\":false,");
                bof_field_str(result, "directory", directory);
                bof_field_str(result, "error", errmsg ? errmsg : "Failed to create parent directory");
                bof_result_trim(result);
                bof_result_append(result, "}");
                bof_result_send(result);
                bof_result_destroy(result);
                if (errmsg) free(errmsg);
                free(partial_path);
                free(path_copy);
                free(directory);
                return;
            }
        }

        free(partial_path);
        *slash = '/';
        current_path = slash + 1;
    }

    free(path_copy);

    int rc = mkdir(directory, mode);
    if (rc != 0 && errno != EEXIST) {
        bof_result_append(result, "{");
        bof_result_append(result, "\"success\":false,");
        bof_field_str(result, "directory", directory);
        bof_field_str(result, "error", strerror(errno));
        bof_result_trim(result);
        bof_result_append(result, "}");
        bof_result_send(result);
        bof_result_destroy(result);
        free(directory);
        return;
    }

    bof_result_append(result, "{");
    bof_result_append(result, "\"success\":true,");
    bof_field_str(result, "directory", directory);
    bof_field_str(result, "mode", "755");
    bof_field_str(result, "message", "Directory created successfully");
    bof_result_trim(result);
    bof_result_append(result, "}");
    bof_result_send(result);
    bof_result_destroy(result);
    free(directory);
}

#else

void coffee(int argc, char **argv) {
    if (argc < 1) {
        BeaconPrintf("Usage: mkdir <directory>");
        BeaconPrintf("Examples:");
        BeaconPrintf("  mkdir /tmp/newdir");
        BeaconPrintf("  mkdir /tmp/path/to/newdir");
        return;
    }

    char *directory = argv[0];
    
    // Default permissions for new directories (755)
    mode_t mode = S_IRWXU | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH;
    
    // Check if directory already exists
    struct stat dir_stat;
    if (stat(directory, &dir_stat) == 0) {
        if (S_ISDIR(dir_stat.st_mode)) {
            char output[1024];
            snprintf(output, sizeof(output), 
                "{\"success\":true,\"directory\":\"%s\",\"message\":\"Directory already exists\"}", 
                directory);
            BeaconOutput(output, strlen(output));
            return;
        } else {
            char output[1024];
            snprintf(output, sizeof(output), 
                "{\"success\":false,\"directory\":\"%s\",\"error\":\"File exists but is not a directory\"}", 
                directory);
            BeaconOutput(output, strlen(output));
            return;
        }
    }
    
    // Create parent directories as needed (always -p behavior)
    char *path_copy = strdup(directory);
    char *current_path = path_copy;
    char *slash;
    
    // Skip initial slash for absolute paths
    if (*current_path == '/') {
        current_path++;
    }
    
    // Create each directory component
    while ((slash = strchr(current_path, '/')) != NULL) {
        *slash = '\0';
        
        // Reconstruct the path up to this point
        char partial_path[1024];
        if (directory[0] == '/') {
            snprintf(partial_path, sizeof(partial_path), "/%s", path_copy);
        } else {
            snprintf(partial_path, sizeof(partial_path), "%s", path_copy);
        }
        
        // Create this directory component if it doesn't exist
        if (stat(partial_path, &dir_stat) != 0) {
            if (mkdir(partial_path, mode) != 0 && errno != EEXIST) {
                char output[1024];
                snprintf(output, sizeof(output), 
                    "{\"success\":false,\"directory\":\"%s\",\"error\":\"Failed to create parent directory '%s': %s\"}", 
                    directory, partial_path, strerror(errno));
                BeaconOutput(output, strlen(output));
                free(path_copy);
                return;
            }
        }
        
        *slash = '/';
        current_path = slash + 1;
    }
    
    free(path_copy);
    
    // Create the final directory
    int result = mkdir(directory, mode);
    if (result != 0 && errno != EEXIST) {
        char output[1024];
        snprintf(output, sizeof(output), 
            "{\"success\":false,\"directory\":\"%s\",\"error\":\"Failed to create directory: %s\"}", 
            directory, strerror(errno));
        BeaconOutput(output, strlen(output));
        return;
    }
    
    // Success
    char output[1024];
    snprintf(output, sizeof(output), 
        "{\"success\":true,\"directory\":\"%s\",\"mode\":\"755\",\"message\":\"Directory created successfully\"}", 
        directory);
    
    BeaconOutput(output, strlen(output));
}
#endif