#ifndef BEACON_H
#define BEACON_H
#include <stdarg.h>

void BeaconOutput(const char *data, int len);
void BeaconPrintf(const char *fmt, ...);

#include "bof_helpers.h"

#endif /* BEACON_H */
