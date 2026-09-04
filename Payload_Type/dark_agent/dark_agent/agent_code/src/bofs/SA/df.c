#include "../includes/beacon.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/statvfs.h>

#ifdef TARGET_MACOS
/* Inline struct statfs to avoid sys/mount.h __asm symbol renaming
 * (__DARWIN_INODE64 maps getmntinfo -> _getmntinfo64 which dlsym can't find). */
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
    char     f_reserved[256];
};
extern int getmntinfo(struct statfs **mntbufp, int flags);

void coffee() {
    struct statfs *mntbuf;
    int count = getmntinfo(&mntbuf, MNT_WAIT);
    if (count == 0) { BeaconPrintf("Error: getmntinfo failed"); return; }

    bof_result_t *b = bof_result_create(INITIAL_BUFFER_SIZE);
    if (!b) { BeaconPrintf("Error: malloc"); return; }

    bof_result_append(b, "{\"filesystems\":[");
    int first = 1;

    for (int i = 0; i < count; i++) {
        if (strncmp(mntbuf[i].f_mntfromname, "/dev/", 5) != 0 &&
            strcmp(mntbuf[i].f_fstypename, "hfs")   != 0 &&
            strcmp(mntbuf[i].f_fstypename, "apfs")  != 0 &&
            strcmp(mntbuf[i].f_fstypename, "exfat") != 0 &&
            strcmp(mntbuf[i].f_fstypename, "msdos") != 0) continue;

        unsigned long long total = (unsigned long long)mntbuf[i].f_blocks * mntbuf[i].f_bsize;
        unsigned long long avail = (unsigned long long)mntbuf[i].f_bavail * mntbuf[i].f_bsize;
        if (total == 0) continue;

        if (!first) bof_result_append(b, ",");
        first = 0;

        bof_result_append(b, "{");
        bof_field_str(b, "device",          mntbuf[i].f_mntfromname);
        bof_field_str(b, "mount_point",     mntbuf[i].f_mntonname);
        bof_field_str(b, "filesystem_type", mntbuf[i].f_fstypename);
        bof_field_ull(b, "total_bytes",     total);
        bof_field_ull(b, "used_bytes",      total > avail ? total - avail : 0);
        bof_field_ull(b, "available_bytes", avail);
        bof_field_int(b, "use_percent",     (int)(((total - avail) * 100) / total));
        bof_result_trim(b);
        bof_result_append(b, "}");
    }

    bof_result_append(b, "]}");
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

    len += snprintf(out + len, bufsz - len, "{\"filesystems\":[");
    struct mntent *entry;
    while ((entry = getmntent(mounts)) != NULL) {
        if (strncmp(entry->mnt_fsname, "/dev/", 5) != 0 &&
            strcmp(entry->mnt_fsname, "tmpfs") != 0 &&
            strcmp(entry->mnt_fsname, "devtmpfs") != 0) continue;

        struct statvfs vfs;
        if (statvfs(entry->mnt_dir, &vfs) != 0) continue;

        unsigned long long total = (unsigned long long)vfs.f_blocks * vfs.f_frsize;
        unsigned long long avail = (unsigned long long)vfs.f_bavail * vfs.f_frsize;
        unsigned long long used  = total > avail ? total - avail : 0;
        if (total == 0) continue;
        int pct = (int)((used * 100) / total);

        char jdev[128], jmnt[256], jtype[64];
        json_escape(jdev,  entry->mnt_fsname, sizeof(jdev));
        json_escape(jmnt,  entry->mnt_dir,    sizeof(jmnt));
        json_escape(jtype, entry->mnt_type,   sizeof(jtype));

        out = ensure_buf(out, &bufsz, len, 1000);
        if (!first) len += snprintf(out + len, bufsz - len, ",");
        first = 0;
        len += snprintf(out + len, bufsz - len,
            "{\"device\":\"%s\",\"mount_point\":\"%s\",\"filesystem_type\":\"%s\","
            "\"total_bytes\":%llu,\"used_bytes\":%llu,\"available_bytes\":%llu,\"use_percent\":%d}",
            jdev, jmnt, jtype, total, used, avail, pct);
    }
    len += snprintf(out + len, bufsz - len, "]}");
    endmntent(mounts);
    BeaconOutput(out, len);
    free(out);
}
#endif
