#include "../includes/beacon.h"
#include <unistd.h>
#include <string.h>

void coffee(int argc, char **argv) {
  char hostname[256];
  if (gethostname(hostname, sizeof(hostname)) == 0) {
    BeaconOutput(hostname, strlen(hostname));
  } else {
    BeaconPrintf("Error: unable to get hostname\n");
  }
}