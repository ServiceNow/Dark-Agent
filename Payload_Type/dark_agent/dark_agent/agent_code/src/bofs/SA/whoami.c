#include "../includes/beacon.h"
#include <unistd.h>
#include <pwd.h>

void coffee() {
    uid_t uid = getuid();
    struct passwd *pw = getpwuid(uid);

    char *name = pw->pw_name;

    if (pw) {
        const char output[] =
          "Current User: %s\n"
          "UID: %d\n";

        BeaconPrintf(output, name, uid);
    } else {
        BeaconPrintf("Current UID: %d\n", uid);
    }
}