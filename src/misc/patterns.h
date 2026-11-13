#pragma once
#include "chart.h"

// Called by chart.c after the original PNG charts have loaded.
void knit_patterns_load(const char* directory);

#ifdef __OBJC__
#import <Foundation/Foundation.h>
NSData* knit_pattern_read(NSURL* url, NSError** error);
BOOL knit_pattern_decode(NSData* data, struct knit_chart* output, NSError** error);
NSData* knit_pattern_encode(const struct knit_chart* chart, NSError** error);
// Always installs a new private copy; never overwrites a pattern or a built-in.
NSString* knit_pattern_install(NSData* data, const char* directory, NSError** error);
NSURL* knit_pattern_trash(const char* directory, NSString* name, NSError** error);
#endif
