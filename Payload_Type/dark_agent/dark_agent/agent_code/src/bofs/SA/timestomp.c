#include "../includes/beacon.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <time.h>
#include <unistd.h>
#include <utime.h>

void coffee(int argc, char **argv) {
    if (argc < 2) {
        BeaconPrintf("Usage: timestomp <target_file> <@reference_file|timestamp>");
        return;
    }

    char *target_file = argv[0];
    char *source_arg = argv[1];
    struct stat target_stat, ref_stat;
    struct utimbuf new_times;
    int result;

    // Check if target file exists
    if (stat(target_file, &target_stat) != 0) {
        BeaconPrintf("Error: Target file '%s' does not exist or cannot be accessed", target_file);
        return;
    }

    // Check if source argument starts with @ (reference file)
    if (source_arg[0] == '@') {
        char *reference_file = source_arg + 1;  // Skip the @ symbol
        
        // Check if reference file exists
        if (stat(reference_file, &ref_stat) != 0) {
            BeaconPrintf("Error: Reference file '%s' does not exist or cannot be accessed", reference_file);
            return;
        }
        
        // Copy timestamps from reference file
        new_times.actime = ref_stat.st_atime;
        new_times.modtime = ref_stat.st_mtime;
        
        BeaconPrintf("Copying timestamps from '%s' to '%s'", reference_file, target_file);
    } else {
        // Parse specific timestamp (format: YYYY-MM-DD HH:MM:SS)
        struct tm tm_time;
        memset(&tm_time, 0, sizeof(tm_time));
        
        if (sscanf(source_arg, "%d-%d-%d %d:%d:%d", 
                   &tm_time.tm_year, &tm_time.tm_mon, &tm_time.tm_mday,
                   &tm_time.tm_hour, &tm_time.tm_min, &tm_time.tm_sec) != 6) {
            BeaconPrintf("Error: Invalid timestamp format. Use YYYY-MM-DD HH:MM:SS");
            return;
        }
        
        // Adjust for struct tm format
        tm_time.tm_year -= 1900;  // Years since 1900
        tm_time.tm_mon -= 1;      // Months since January (0-11)
        tm_time.tm_isdst = -1;    // Let mktime determine DST
        
        time_t timestamp = mktime(&tm_time);
        if (timestamp == -1) {
            BeaconPrintf("Error: Invalid timestamp provided");
            return;
        }
        
        // Set both access and modification times to the specified timestamp
        new_times.actime = timestamp;
        new_times.modtime = timestamp;
        
        BeaconPrintf("Setting timestamp '%s' on file '%s'", source_arg, target_file);
    }

    // Apply the new timestamps
    result = utime(target_file, &new_times);
    if (result != 0) {
        BeaconPrintf("Error: Failed to modify timestamps for '%s'", target_file);
        return;
    }

    // Verify the change
    struct stat new_stat;
    if (stat(target_file, &new_stat) == 0) {
        char atime_str[64], mtime_str[64];
        struct tm *tm_atime = localtime(&new_stat.st_atime);
        struct tm *tm_mtime = localtime(&new_stat.st_mtime);
        
        strftime(atime_str, sizeof(atime_str), "%Y-%m-%d %H:%M:%S", tm_atime);
        strftime(mtime_str, sizeof(mtime_str), "%Y-%m-%d %H:%M:%S", tm_mtime);
        
        BeaconPrintf("Success: Timestamps modified");
        BeaconPrintf("Access time:  %s", atime_str);
        BeaconPrintf("Modify time:  %s", mtime_str);
    } else {
        BeaconPrintf("Success: Timestamps modified (verification failed)");
    }
}