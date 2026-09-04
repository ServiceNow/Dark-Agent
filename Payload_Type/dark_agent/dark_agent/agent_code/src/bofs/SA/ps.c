#include "../includes/beacon.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <pwd.h>
#include <dirent.h>

#ifdef TARGET_MACOS
#include <stdint.h>

#define PBSD_SIZE     512
#define PBSD_PID_OFF   12
#define PBSD_PPID_OFF  16
#define PBSD_RUID_OFF  28
#define PBSD_COMM_OFF  48
#define PBSD_NAME_OFF  64

#define PROC_ALL_PIDS        1
#define PROC_PIDTBSDINFO     3
#define PROC_PIDPATHINFO_MAXSIZE 4096

extern int proc_listpids(uint32_t type, uint32_t typeinfo, void *buf, int bufsz);
extern int proc_pidinfo(int pid, int flavor, uint64_t arg, void *buf, int bufsz);
extern int proc_pidpath(int pid, void *buf, uint32_t bufsz);

void coffee(void) {
    int pid_bytes = proc_listpids(PROC_ALL_PIDS, 0, NULL, 0);
    if (pid_bytes <= 0) { BeaconPrintf("Error: proc_listpids sizing"); return; }

    int32_t *pids = (int32_t *)malloc((size_t)pid_bytes);
    if (!pids) { BeaconPrintf("Error: malloc"); return; }

    int filled = proc_listpids(PROC_ALL_PIDS, 0, pids, pid_bytes);
    if (filled <= 0) { free(pids); BeaconPrintf("Error: proc_listpids fill"); return; }
    int nprocs = filled / (int)sizeof(int32_t);

    /* heap buffers for per-process data */
    char *bsdinfo  = (char *)malloc(PBSD_SIZE);
    char *bin_path = (char *)malloc(PROC_PIDPATHINFO_MAXSIZE);
    char *username = (char *)malloc(64);
    if (!bsdinfo || !bin_path || !username) {
        free(pids); free(bsdinfo); free(bin_path); free(username);
        BeaconPrintf("Error: malloc"); return;
    }

    bof_result_t *b = bof_result_create(INITIAL_BUFFER_SIZE + nprocs * 512);
    if (!b) {
        free(pids); free(bsdinfo); free(bin_path); free(username);
        BeaconPrintf("Error: malloc"); return;
    }

    bof_result_append(b, "{\"processes\":[\n");
    int first = 1;

    for (int i = 0; i < nprocs; i++) {
        int pid_val = (int)pids[i];
        if (pid_val <= 0) continue;

        memset(bsdinfo, 0, PBSD_SIZE);
        if (proc_pidinfo(pid_val, PROC_PIDTBSDINFO, 0, bsdinfo, PBSD_SIZE) <= 0)
            continue;

        /*
         * All local int/pointer variables (bsd_pid etc.) are subject to
         * stack corruption across function calls in the BOF ABI context.
         * Read bsdinfo fields directly at the point of use never via cached
         * local variables that survive across external function calls.
         */

        /* bin_path: prefer proc_pidpath; fall back to name from bsdinfo */
        memset(bin_path, 0, PROC_PIDPATHINFO_MAXSIZE);
        if (proc_pidpath(pid_val, bin_path, PROC_PIDPATHINFO_MAXSIZE) <= 0) {
            const char *nm = bsdinfo[PBSD_NAME_OFF] ? bsdinfo + PBSD_NAME_OFF
                                                     : bsdinfo + PBSD_COMM_OFF;
            strncpy(bin_path, nm, PROC_PIDPATHINFO_MAXSIZE - 1);
            bin_path[PROC_PIDPATHINFO_MAXSIZE - 1] = '\0';
        }

        /* username: read ruid directly from bsdinfo heap */
        struct passwd *pw = getpwuid((uid_t)*(uint32_t *)(bsdinfo + PBSD_RUID_OFF));
        if (pw) {
            strncpy(username, pw->pw_name, 63);
            username[63] = '\0';
        } else {
            int upos = 0; char tmp[24]; int n = (int)*(uint32_t *)(bsdinfo + PBSD_RUID_OFF);
            if (n == 0) { tmp[upos++] = '0'; }
            else { while (n > 0) { tmp[upos++] = (char)('0' + n % 10); n /= 10; }
                   for (int a = 0, z = upos-1; a < z; a++, z--) { char t=tmp[a]; tmp[a]=tmp[z]; tmp[z]=t; } }
            tmp[upos] = '\0';
            strncpy(username, tmp, 63); username[63] = '\0';
        }

        if (!first) bof_result_append(b, ",\n");
        first = 0;

        bof_result_append(b, "{");
        bof_field_int(b, "process_id",        (int)*(uint32_t *)(bsdinfo + PBSD_PID_OFF));
        bof_field_int(b, "parent_process_id", (int)*(uint32_t *)(bsdinfo + PBSD_PPID_OFF));
        bof_field_str(b, "user",              username);
        bof_field_str(b, "bin_path",          bin_path);
        bof_field_str(b, "command_line",      bin_path);
        bof_field_str(b, "name",              bsdinfo[PBSD_NAME_OFF] ? bsdinfo + PBSD_NAME_OFF
                                                                     : bsdinfo + PBSD_COMM_OFF);
        bof_result_trim(b);
        bof_result_append(b, "}");
    }

    bof_result_append(b, "\n]}");

    free(pids); free(bsdinfo); free(bin_path); free(username);
    bof_result_send(b);
    bof_result_destroy(b);
}

#else

void coffee() {
    DIR *proc_dir;
    struct dirent *entry;
    FILE *status_file, *cmdline_file;
    char status_path[256], cmdline_path[256], exe_path[256];
    char line[512], name[64], cmdline[2048], bin_path[512], username[64];
    char json_name[128], json_cmdline[4096], json_binpath[1024], json_username[64];
    long pid, ppid, uid = -1;
    char *output;
    int total_len = 0, buffer_size = INITIAL_BUFFER_SIZE, first_process = 1;

    output = malloc(buffer_size);
    if (!output) { BeaconPrintf("Error: malloc failed\n"); return; }

    proc_dir = opendir("/proc");
    if (!proc_dir) { BeaconPrintf("Error: Unable to open /proc directory\n"); free(output); return; }

    total_len += snprintf(output + total_len, buffer_size - total_len, "{\"processes\":[\n");

    while ((entry = readdir(proc_dir)) != NULL) {
        if (strspn(entry->d_name, "0123456789") != strlen(entry->d_name)) continue;
        pid = strtol(entry->d_name, NULL, 10);

        memset(name, 0, sizeof(name));
        memset(cmdline, 0, sizeof(cmdline));
        memset(bin_path, 0, sizeof(bin_path));
        memset(username, 0, sizeof(username));
        ppid = 0; uid = -1;

        snprintf(status_path, sizeof(status_path), "/proc/%s/status", entry->d_name);
        status_file = fopen(status_path, "r");
        if (!status_file) continue;

        while (fgets(line, sizeof(line), status_file)) {
            if      (!strncmp(line, "Name:", 5))  sscanf(line, "Name:\t%63s", name);
            else if (!strncmp(line, "PPid:", 5))  sscanf(line, "PPid:\t%ld", &ppid);
            else if (!strncmp(line, "Uid:",  4))  sscanf(line, "Uid:\t%ld", &uid);
        }
        fclose(status_file);

        snprintf(exe_path, sizeof(exe_path), "/proc/%s/exe", entry->d_name);
        ssize_t elen = readlink(exe_path, bin_path, sizeof(bin_path) - 1);
        if (elen > 0) bin_path[elen] = '\0';
        else strncpy(bin_path, name, sizeof(bin_path) - 1);

        snprintf(cmdline_path, sizeof(cmdline_path), "/proc/%s/cmdline", entry->d_name);
        cmdline_file = fopen(cmdline_path, "r");
        int is_kthread = 0;
        if (cmdline_file) {
            size_t br = fread(cmdline, 1, sizeof(cmdline) - 1, cmdline_file);
            if (br > 0 && cmdline[0] != '\0') {
                for (size_t k = 0; k < br; k++) if (cmdline[k] == '\0' && k < br-1) cmdline[k] = ' ';
                cmdline[br] = '\0';
                int cl = strlen(cmdline);
                while (cl > 0 && cmdline[cl-1] == ' ') cmdline[--cl] = '\0';
            } else is_kthread = 1;
            fclose(cmdline_file);
        } else is_kthread = 1;

        if (is_kthread) {
            snprintf(cmdline, sizeof(cmdline), "[%s]", name);
            strncpy(bin_path, "[kernel]", sizeof(bin_path) - 1);
        }

        struct passwd *pwd = getpwuid((uid_t)uid);
        if (pwd) snprintf(username, sizeof(username), "%s (%ld)", pwd->pw_name, uid);
        else     snprintf(username, sizeof(username), "%ld", uid);

        json_escape(json_username, username, sizeof(json_username));
        json_escape(json_binpath,  bin_path, sizeof(json_binpath));
        json_escape(json_cmdline,  cmdline,  sizeof(json_cmdline));
        json_escape(json_name,     name,     sizeof(json_name));

        output = ensure_buf(output, &buffer_size, total_len, 1000);

        if (!first_process) total_len += snprintf(output + total_len, buffer_size - total_len, ",\n");
        first_process = 0;

        total_len += snprintf(output + total_len, buffer_size - total_len,
            "{\"process_id\":%ld,\"parent_process_id\":%ld,\"user\":\"%s\","
            "\"bin_path\":\"%s\",\"command_line\":\"%s\",\"name\":\"%s\"}",
            pid, ppid, json_username, json_binpath, json_cmdline, json_name);
    }

    total_len += snprintf(output + total_len, buffer_size - total_len, "\n]}");
    closedir(proc_dir);
    BeaconOutput(output, total_len);
    free(output);
}
#endif
