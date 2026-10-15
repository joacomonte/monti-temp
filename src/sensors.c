#include <IOKit/hidsystem/IOHIDEventSystemClient.h>
#include <CoreFoundation/CoreFoundation.h>
#include <string.h>
#include "sensors.h"

// APIs privadas de IOKit (sensores HID en Apple Silicon)
typedef struct __IOHIDEvent *IOHIDEventRef;
typedef struct __IOHIDServiceClient *IOHIDServiceClientRef;
IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef);
int IOHIDEventSystemClientSetMatching(IOHIDEventSystemClientRef, CFDictionaryRef);
IOHIDEventRef IOHIDServiceClientCopyEvent(IOHIDServiceClientRef, int64_t, int32_t, int64_t);
double IOHIDEventGetFloatValue(IOHIDEventRef, int32_t);
CFTypeRef IOHIDServiceClientCopyProperty(IOHIDServiceClientRef, CFStringRef);

#define kTempEvent 15

void read_groups(double out[4]) {
    static IOHIDEventSystemClientRef client = NULL;
    if (!client) {
        client = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
        int page = 0xff00, usage = 5;
        CFNumberRef p = CFNumberCreate(NULL, kCFNumberIntType, &page);
        CFNumberRef u = CFNumberCreate(NULL, kCFNumberIntType, &usage);
        const void *k[] = { CFSTR("PrimaryUsagePage"), CFSTR("PrimaryUsage") };
        const void *v[] = { p, u };
        CFDictionaryRef match = CFDictionaryCreate(NULL, k, v, 2, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        IOHIDEventSystemClientSetMatching(client, match);
        CFRelease(match); CFRelease(p); CFRelease(u);
    }
    static const char *prefixes[4] = { "PMU tdie", "PMU TP", "NAND", "gas gauge" };
    for (int g = 0; g < 4; g++) out[g] = -1;
    CFArrayRef services = IOHIDEventSystemClientCopyServices(client);
    if (!services) return;
    for (CFIndex i = 0; i < CFArrayGetCount(services); i++) {
        IOHIDServiceClientRef s = (IOHIDServiceClientRef)CFArrayGetValueAtIndex(services, i);
        IOHIDEventRef e = IOHIDServiceClientCopyEvent(s, kTempEvent, 0, 0);
        if (!e) continue;
        double t = IOHIDEventGetFloatValue(e, kTempEvent << 16);
        CFRelease(e);
        if (t <= 0 || t >= 150) continue;
        char name[64] = "";
        CFStringRef product = IOHIDServiceClientCopyProperty(s, CFSTR("Product"));
        if (product) { CFStringGetCString(product, name, sizeof name, kCFStringEncodingUTF8); CFRelease(product); }
        for (int g = 0; g < 4; g++)
            if (strncmp(name, prefixes[g], strlen(prefixes[g])) == 0 && t > out[g]) out[g] = t;
    }
    CFRelease(services);
}
