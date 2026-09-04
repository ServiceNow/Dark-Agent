#include "../includes/beacon.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>
#include <pwd.h>
#include <grp.h>
#include <errno.h>

#ifdef TARGET_MACOS

void coffee(int argc, char **argv) {
    if (argc < 2) {
        BeaconPrintf("Usage: chown <owner[:group]> <filepath>");
        BeaconPrintf("Examples:");
        BeaconPrintf("  chown root /tmp/file");
        BeaconPrintf("  chown root:wheel /tmp/file");
        BeaconPrintf("  chown :staff /tmp/file");
        return;
    }

    char *owner_group = (char *)malloc(strlen(argv[0]) + 1);
    char *filepath    = (char *)malloc(strlen(argv[1]) + 1);
    if (!owner_group || !filepath) {
        free(owner_group); free(filepath);
        BeaconPrintf("Error: malloc");
        return;
    }
    strcpy(owner_group, argv[0]);
    strcpy(filepath, argv[1]);

    char *owner_str = NULL;
    char *group_str = NULL;
    char *colon_pos = strchr(owner_group, ':');

    if (colon_pos != NULL) {
        size_t owner_len = (size_t)(colon_pos - owner_group);
        if (owner_len > 0) {
            owner_str = (char *)malloc(owner_len + 1);
            if (!owner_str) { free(owner_group); free(filepath); BeaconPrintf("Error: malloc"); return; }
            strncpy(owner_str, owner_group, owner_len);
            owner_str[owner_len] = '\0';
        }
        group_str = colon_pos + 1;
        if (strlen(group_str) == 0) group_str = NULL;
    } else {
        owner_str = owner_group;
    }

    struct stat file_stat;
    if (stat(filepath, &file_stat) != 0) {
        bof_result_t *result = bof_result_create(256);
        if (!result) {
            if (owner_str != owner_group) free(owner_str);
            free(owner_group); free(filepath);
            BeaconPrintf("Error: malloc"); return;
        }
        bof_result_append(result, "{");
        bof_result_append(result, "\"success\":false,");
        bof_field_str(result, "filepath", filepath);
        bof_field_str(result, "error", strerror(errno));
        bof_result_trim(result);
        bof_result_append(result, "}");
        bof_result_send(result);
        bof_result_destroy(result);
        if (owner_str != owner_group) free(owner_str);
        free(owner_group); free(filepath);
        return;
    }

    uid_t old_uid = file_stat.st_uid;
    gid_t old_gid = file_stat.st_gid;
    uid_t new_uid = old_uid;
    gid_t new_gid = old_gid;

    if (owner_str != NULL && strlen(owner_str) > 0) {
        struct passwd *pwd = getpwnam(owner_str);
        if (pwd != NULL) {
            new_uid = pwd->pw_uid;
        } else {
            char *endptr;
            long uid_long = strtol(owner_str, &endptr, 10);
            if (*endptr == '\0' && uid_long >= 0) {
                new_uid = (uid_t)uid_long;
            } else {
                bof_result_t *result = bof_result_create(256);
                if (!result) {
                    if (owner_str != owner_group) free(owner_str);
                    free(owner_group); free(filepath);
                    BeaconPrintf("Error: malloc"); return;
                }
                bof_result_append(result, "{");
                bof_result_append(result, "\"success\":false,");
                bof_field_str(result, "error", "Unknown user");
                bof_result_trim(result);
                bof_result_append(result, "}");
                bof_result_send(result);
                bof_result_destroy(result);
                if (owner_str != owner_group) free(owner_str);
                free(owner_group); free(filepath);
                return;
            }
        }
    }

    if (group_str != NULL && strlen(group_str) > 0) {
        struct group *grp = getgrnam(group_str);
        if (grp != NULL) {
            new_gid = grp->gr_gid;
        } else {
            char *endptr;
            long gid_long = strtol(group_str, &endptr, 10);
            if (*endptr == '\0' && gid_long >= 0) {
                new_gid = (gid_t)gid_long;
            } else {
                bof_result_t *result = bof_result_create(256);
                if (!result) {
                    if (owner_str != owner_group) free(owner_str);
                    free(owner_group); free(filepath);
                    BeaconPrintf("Error: malloc"); return;
                }
                bof_result_append(result, "{");
                bof_result_append(result, "\"success\":false,");
                bof_field_str(result, "error", "Unknown group");
                bof_result_trim(result);
                bof_result_append(result, "}");
                bof_result_send(result);
                bof_result_destroy(result);
                if (owner_str != owner_group) free(owner_str);
                free(owner_group); free(filepath);
                return;
            }
        }
    }

    if (chown(filepath, new_uid, new_gid) != 0) {
        bof_result_t *result = bof_result_create(256);
        if (!result) {
            if (owner_str != owner_group) free(owner_str);
            free(owner_group); free(filepath);
            BeaconPrintf("Error: malloc"); return;
        }
        bof_result_append(result, "{");
        bof_result_append(result, "\"success\":false,");
        bof_field_str(result, "filepath", filepath);
        bof_field_str(result, "error", strerror(errno));
        bof_result_trim(result);
        bof_result_append(result, "}");
        bof_result_send(result);
        bof_result_destroy(result);
        if (owner_str != owner_group) free(owner_str);
        free(owner_group); free(filepath);
        return;
    }

    char *old_owner_name = (char *)malloc(64);
    char *new_owner_name = (char *)malloc(64);
    if (!old_owner_name || !new_owner_name) {
        free(old_owner_name); free(new_owner_name);
        if (owner_str != owner_group) free(owner_str);
        free(owner_group); free(filepath);
        BeaconPrintf("Error: malloc"); return;
    }
    strcpy(old_owner_name, "unknown");
    strcpy(new_owner_name, "unknown");

    struct passwd *old_pwd = getpwuid(old_uid);
    if (old_pwd) strncpy(old_owner_name, old_pwd->pw_name, 63);
    old_owner_name[63] = '\0';

    struct passwd *new_pwd = getpwuid(new_uid);
    if (new_pwd) strncpy(new_owner_name, new_pwd->pw_name, 63);
    new_owner_name[63] = '\0';

    bof_result_t *result = bof_result_create(512);
    if (!result) {
        free(old_owner_name); free(new_owner_name);
        if (owner_str != owner_group) free(owner_str);
        free(owner_group); free(filepath);
        BeaconPrintf("Error: malloc"); return;
    }
    bof_result_append(result, "{");
    bof_result_append(result, "\"success\":true,");
    bof_field_str(result, "filepath", filepath);
    bof_field_str(result, "old_owner", old_owner_name);
    bof_field_str(result, "new_owner", new_owner_name);
    bof_field_str(result, "message", "Ownership changed successfully");
    bof_result_trim(result);
    bof_result_append(result, "}");
    bof_result_send(result);
    bof_result_destroy(result);

    free(old_owner_name); free(new_owner_name);
    if (owner_str != owner_group) free(owner_str);
    free(owner_group); free(filepath);
}

#else

void coffee(int argc, char **argv) {
    if (argc < 2) {
        BeaconPrintf("Usage: chown <owner[:group]> <filepath>");
        BeaconPrintf("Examples:");
        BeaconPrintf("  chown root /tmp/file");
        BeaconPrintf("  chown root:wheel /tmp/file");
        BeaconPrintf("  chown :staff /tmp/file");
        return;
    }

    char *owner_group = argv[0];
    char *filepath = argv[1];
    
    // Parse owner and group
    char *owner_str = NULL;
    char *group_str = NULL;
    char *colon_pos = strchr(owner_group, ':');
    
    if (colon_pos != NULL) {
        // Split owner:group
        size_t owner_len = colon_pos - owner_group;
        if (owner_len > 0) {
            owner_str = malloc(owner_len + 1);
            strncpy(owner_str, owner_group, owner_len);
            owner_str[owner_len] = '\0';
        }
        group_str = colon_pos + 1;
        if (strlen(group_str) == 0) {
            group_str = NULL;
        }
    } else {
        // Only owner specified
        owner_str = owner_group;
    }
    
    // Check if file exists
    struct stat file_stat;
    if (stat(filepath, &file_stat) != 0) {
        char output[1024];
        snprintf(output, sizeof(output), 
            "{\"success\":false,\"filepath\":\"%s\",\"error\":\"File does not exist or cannot be accessed: %s\"}", 
            filepath, strerror(errno));
        BeaconOutput(output, strlen(output));
        if (owner_str != owner_group) free(owner_str);
        return;
    }
    
    // Get current owner/group for comparison
    uid_t old_uid = file_stat.st_uid;
    gid_t old_gid = file_stat.st_gid;
    
    // Resolve new owner
    uid_t new_uid = old_uid;  // Keep current if not specified
    if (owner_str != NULL && strlen(owner_str) > 0) {
        struct passwd *pwd = getpwnam(owner_str);
        if (pwd != NULL) {
            new_uid = pwd->pw_uid;
        } else {
            // Try to parse as numeric UID
            char *endptr;
            long uid_long = strtol(owner_str, &endptr, 10);
            if (*endptr == '\0' && uid_long >= 0) {
                new_uid = (uid_t)uid_long;
            } else {
                char output[1024];
                snprintf(output, sizeof(output), 
                    "{\"success\":false,\"error\":\"Unknown user '%s'\"}", 
                    owner_str);
                BeaconOutput(output, strlen(output));
                if (owner_str != owner_group) free(owner_str);
                return;
            }
        }
    }
    
    // Resolve new group
    gid_t new_gid = old_gid;  // Keep current if not specified
    if (group_str != NULL && strlen(group_str) > 0) {
        struct group *grp = getgrnam(group_str);
        if (grp != NULL) {
            new_gid = grp->gr_gid;
        } else {
            // Try to parse as numeric GID
            char *endptr;
            long gid_long = strtol(group_str, &endptr, 10);
            if (*endptr == '\0' && gid_long >= 0) {
                new_gid = (gid_t)gid_long;
            } else {
                char output[1024];
                snprintf(output, sizeof(output), 
                    "{\"success\":false,\"error\":\"Unknown group '%s'\"}", 
                    group_str);
                BeaconOutput(output, strlen(output));
                if (owner_str != owner_group) free(owner_str);
                return;
            }
        }
    }
    
    // Change ownership
    if (chown(filepath, new_uid, new_gid) != 0) {
        char output[1024];
        snprintf(output, sizeof(output), 
            "{\"success\":false,\"filepath\":\"%s\",\"error\":\"Failed to change ownership: %s\"}", 
            filepath, strerror(errno));
        BeaconOutput(output, strlen(output));
        if (owner_str != owner_group) free(owner_str);
        return;
    }
    
    // Get owner/group names for output
    char old_owner[64] = "unknown";
    char new_owner[64] = "unknown";
    char old_group[64] = "unknown";
    char new_group[64] = "unknown";
    
    struct passwd *old_pwd = getpwuid(old_uid);
    if (old_pwd) strncpy(old_owner, old_pwd->pw_name, sizeof(old_owner) - 1);
    
    struct passwd *new_pwd = getpwuid(new_uid);
    if (new_pwd) strncpy(new_owner, new_pwd->pw_name, sizeof(new_owner) - 1);
    
    struct group *old_grp = getgrgid(old_gid);
    if (old_grp) strncpy(old_group, old_grp->gr_name, sizeof(old_group) - 1);
    
    struct group *new_grp = getgrgid(new_gid);
    if (new_grp) strncpy(new_group, new_grp->gr_name, sizeof(new_group) - 1);
    
    // Format output as JSON
    char output[2048];
    snprintf(output, sizeof(output), 
        "{\"success\":true,\"filepath\":\"%s\",\"old_owner\":\"%s\",\"new_owner\":\"%s\",\"old_group\":\"%s\",\"new_group\":\"%s\",\"old_uid\":%u,\"new_uid\":%u,\"old_gid\":%u,\"new_gid\":%u,\"message\":\"Ownership changed successfully\"}", 
        filepath, old_owner, new_owner, old_group, new_group, old_uid, new_uid, old_gid, new_gid);
    
    BeaconOutput(output, strlen(output));
    
    // Cleanup
    if (owner_str != owner_group) free(owner_str);
}
#endif