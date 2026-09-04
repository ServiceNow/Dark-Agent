#include "../includes/beacon.h"

#ifdef TARGET_MACOS
#include <sys/sysctl.h>
#include <sys/time.h>
#include <time.h>

void coffee() {
    struct timeval boottime;
    size_t len = sizeof(boottime);
    int mib[] = {CTL_KERN, KERN_BOOTTIME};

    if (sysctl(mib, 2, &boottime, &len, NULL, 0) != 0) {
        BeaconPrintf("Error getting boot time\n");
        return;
    }

    long uptime = (long)(time(NULL) - boottime.tv_sec);
    int days    = uptime / 86400;
    int hours   = (uptime % 86400) / 3600;
    int minutes = (uptime % 3600) / 60;
    int seconds = uptime % 60;

    BeaconPrintf("System Uptime: %d days, %d hours, %d minutes, %d seconds", days, hours, minutes, seconds);
}

#else
#include <sys/sysinfo.h>

void coffee() {
    struct sysinfo info;
    if (sysinfo(&info) != 0) {
        BeaconPrintf("Error getting system information\n");
        return;
    }

    long uptime = info.uptime;
    int days    = uptime / 86400;
    int hours   = (uptime % 86400) / 3600;
    int minutes = (uptime % 3600) / 60;
    int seconds = uptime % 60;

    BeaconPrintf("System Uptime: %d days, %d hours, %d minutes, %d seconds", days, hours, minutes, seconds);
}
#endif
