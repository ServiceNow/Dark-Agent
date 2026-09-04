#include "../includes/beacon.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

/* utmpx is POSIX and available on both Linux and macOS */
#include <utmpx.h>

void coffee() {
    char *out = malloc(INITIAL_BUFFER_SIZE);
    if (!out) { BeaconPrintf("Error: malloc failed"); return; }
    int len = 0, first = 1, count = 0;

    len += snprintf(out + len, INITIAL_BUFFER_SIZE - len, "{\"login_history\":[");

    setutxent();
    struct utmpx *entry;
    while ((entry = getutxent()) != NULL && count < 50) {
        if (entry->ut_type != USER_PROCESS && entry->ut_type != BOOT_TIME) continue;

        char user[64], line[64], host[256], tstr[64];
        strncpy(user, entry->ut_user, sizeof(user) - 1); user[sizeof(user)-1] = '\0';
        strncpy(line, entry->ut_line, sizeof(line) - 1); line[sizeof(line)-1] = '\0';
        strncpy(host, entry->ut_host, sizeof(host) - 1); host[sizeof(host)-1] = '\0';

        if (strlen(user) == 0 && entry->ut_type != BOOT_TIME) continue;

        time_t ts = (time_t)entry->ut_tv.tv_sec;
        struct tm *tm_info = localtime(&ts);
        strftime(tstr, sizeof(tstr), "%Y-%m-%d %H:%M:%S", tm_info);

        const char *logout = "still logged in";
        if (entry->ut_type == BOOT_TIME) {
            strcpy(user, "reboot");
            logout = "system boot";
        }

        const char *stype = "local";
        if      (entry->ut_type == BOOT_TIME)      stype = "boot";
        else if (strstr(line, "pts/") || strstr(line, "s0") || strstr(line, "s00")) stype = "ssh";
        else if (strstr(line, "tty") || strstr(line, "console")) stype = "console";
        else if (strlen(host) > 0)                 stype = "remote";

        char ju[128], jl[128], jh[512];
        json_escape(ju, user, sizeof(ju));
        json_escape(jl, line, sizeof(jl));
        json_escape(jh, host, sizeof(jh));

        if (!first) len += snprintf(out + len, INITIAL_BUFFER_SIZE - len, ",");
        first = 0;
        len += snprintf(out + len, INITIAL_BUFFER_SIZE - len,
            "{\"user\":\"%s\",\"terminal\":\"%s\",\"host\":\"%s\","
            "\"login_time\":\"%s\",\"logout_time\":\"%s\",\"session_type\":\"%s\",\"pid\":%d}",
            ju, jl, jh, tstr, logout, stype, entry->ut_pid);
        count++;
    }
    endutxent();

    len += snprintf(out + len, INITIAL_BUFFER_SIZE - len, "]}");
    BeaconOutput(out, len);
    free(out);
}
