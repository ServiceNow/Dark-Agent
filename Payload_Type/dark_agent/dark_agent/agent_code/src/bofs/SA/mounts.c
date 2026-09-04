#include "../includes/beacon.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef TARGET_MACOS
#include <stdint.h>
#define MFSTYPENAMELEN 16
#define MAXPATHLEN     1024
#define MNT_WAIT       1
#define MNT_RDONLY     0x00000001
#define MNT_NOEXEC     0x00000004
#define MNT_NOSUID     0x00000008

struct statfs {
    uint32_t f_bsize;
    int32_t  f_iosize;
    uint64_t f_blocks;
    uint64_t f_bfree;
    uint64_t f_bavail;
    uint64_t f_files;
    uint64_t f_ffree;
    int32_t  f_fsid[2];
    uint32_t f_owner;
    uint32_t f_type;
    uint32_t f_flags;
    uint32_t f_fssubtype;
    char     f_fstypename[MFSTYPENAMELEN];
    char     f_mntonname[MAXPATHLEN];
    char     f_mntfromname[MAXPATHLEN];
    char     f_reserved[32];
};
extern int getmntinfo(struct statfs **mntbufp, int flags);

void coffee() {
    struct statfs *mntbuf;
    int count = getmntinfo(&mntbuf, MNT_WAIT);
    if (count == 0) { BeaconPrintf("Error: getmntinfo failed"); return; }

    /* opts built per-entry; heap-allocated to avoid stack overflow in BOF thread */
    char *opts = malloc(256);
    if (!opts) { BeaconPrintf("Error: malloc"); return; }

    bof_result_t *b = bof_result_create(INITIAL_BUFFER_SIZE);
    if (!b) { free(opts); BeaconPrintf("Error: malloc"); return; }

    bof_result_append(b, "{\"mounts\":[");
    int first = 1;

    for (int i = 0; i < count; i++) {
        opts[0] = '\0';
        if (mntbuf[i].f_flags & MNT_RDONLY) strncat(opts, "ro,",     255 - (int)strlen(opts));
        if (mntbuf[i].f_flags & MNT_NOEXEC) strncat(opts, "noexec,", 255 - (int)strlen(opts));
        if (mntbuf[i].f_flags & MNT_NOSUID) strncat(opts, "nosuid,", 255 - (int)strlen(opts));
        int ol = (int)strlen(opts);
        if (ol > 0) opts[ol - 1] = '\0';

        if (!first) bof_result_append(b, ",");
        first = 0;

        bof_result_append(b, "{");
        bof_field_str(b, "device",          mntbuf[i].f_mntfromname);
        bof_field_str(b, "mount_point",     mntbuf[i].f_mntonname);
        bof_field_str(b, "filesystem_type", mntbuf[i].f_fstypename);
        bof_field_str(b, "options",         opts);
        bof_result_trim(b);
        bof_result_append(b, "}");
    }

    bof_result_append(b, "]}");
    free(opts);
    bof_result_send(b);
    bof_result_destroy(b);
}

#else
#include <mntent.h>
#include <unistd.h>

void coffee() {
    FILE *mounts = setmntent("/proc/mounts", "r");
    if (!mounts) { BeaconPrintf("Error: Could not read /proc/mounts"); return; }

    int bufsz = INITIAL_BUFFER_SIZE, len = 0, first = 1;
    char *out = malloc(bufsz);
    if (!out) { BeaconPrintf("Error: malloc failed"); endmntent(mounts); return; }

    len += snprintf(out + len, bufsz - len, "{\"mounts\":[");
    struct mntent *entry;
    while ((entry = getmntent(mounts)) != NULL) {
        char jdev[256], jmnt[512], jtype[128], jopts[1024];
        json_escape(jdev,  entry->mnt_fsname, sizeof(jdev));
        json_escape(jmnt,  entry->mnt_dir,    sizeof(jmnt));
        json_escape(jtype, entry->mnt_type,   sizeof(jtype));
        json_escape(jopts, entry->mnt_opts,   sizeof(jopts));

        out = ensure_buf(out, &bufsz, len, 2000);
        if (!first) len += snprintf(out + len, bufsz - len, ",");
        first = 0;
        len += snprintf(out + len, bufsz - len,
            "{\"device\":\"%s\",\"mount_point\":\"%s\",\"filesystem_type\":\"%s\",\"options\":\"%s\"}",
            jdev, jmnt, jtype, jopts);
    }
    len += snprintf(out + len, bufsz - len, "]}");
    endmntent(mounts);
    BeaconOutput(out, len);
    free(out);
}
#endif
