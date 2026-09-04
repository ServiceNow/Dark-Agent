#include "includes/beacon.h"

void coffee() {
    const char coffee[] =
      "\n"
      "        ( (      \n"
      "        ) )      \n"
      "     .______.    \n"
      "     |      |]   \n"
      "     \\      /    \n"
      "      `----'     \n";

    BeaconOutput((char*)coffee, sizeof(coffee) - 1);
}