#include "../includes/beacon.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#define MAX_FILE_SIZE 10485760  // 10MB limit

void coffee(int argc, char **argv) {
    if (argc < 1) {
        BeaconPrintf("Usage: cat <filepath>");
        return;
    }

    char *filepath = argv[0];
    if (!filepath || filepath[0] == '\0') {
        BeaconPrintf("Usage: cat <filepath>");
        return;
    }

    struct stat file_stat;

    if (stat(filepath, &file_stat) != 0) {
        BeaconPrintf("No such file: %s", filepath);
        return;
    }

    if (!S_ISREG(file_stat.st_mode)) {
        BeaconPrintf("Error: '%s' is not a regular file", filepath);
        return;
    }

    if (file_stat.st_size > MAX_FILE_SIZE) {
        BeaconPrintf("Error: File '%s' exceeds 10MB limit", filepath);
        return;
    }

    FILE *file = fopen(filepath, "r");
    if (file == NULL) {
        BeaconPrintf("Error: Cannot open file '%s'", filepath);
        return;
    }

    char *file_content = malloc(file_stat.st_size + 1);
    if (file_content == NULL) {
        BeaconPrintf("Error: Unable to allocate memory for file content");
        fclose(file);
        return;
    }

    size_t bytes_read = fread(file_content, 1, file_stat.st_size, file);
    file_content[bytes_read] = '\0';
    fclose(file);

    BeaconOutput(file_content, bytes_read);
    free(file_content);
}
