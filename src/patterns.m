#import "misc/patterns.h"
#include <errno.h>
#include <math.h>
#include <stdio.h>

static BOOL pattern_error(NSError** error, NSString* message) {
  if (error) *error = [NSError errorWithDomain:@"WindowFestival.Pattern" code:1
      userInfo:@{NSLocalizedDescriptionKey: message}];
  return NO;
}
static BOOL pattern_color(id value, uint32_t* color) {
  if (![value isKindOfClass:NSString.class] || [value length] != 7 || ![value hasPrefix:@"#"]) return NO;
  const char* s = [value UTF8String];
  if (!s || strlen(s) != 7) return NO;
  uint32_t n = 0;
  for (int i = 1; i < 7; i++) {
    char c = s[i]; int digit = c >= '0' && c <= '9' ? c-'0'
        : c >= 'a' && c <= 'f' ? c-'a'+10 : c >= 'A' && c <= 'F' ? c-'A'+10 : -1;
    if (digit < 0) return NO;
    n = n*16 + digit;
  }
  *color = 0xff000000u | n;
  return YES;
}
static BOOL pattern_number(id value, float low, float high) {
  if (![value isKindOfClass:NSNumber.class] || CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID()) return NO;
  double n = [value doubleValue];
  return isfinite(n) && n >= low && n <= high;
}

NSData* knit_pattern_read(NSURL* url, NSError** error) {
  if (!url.isFileURL) { pattern_error(error, @"请选择本地的 .knit.json 图案包。"); return nil; }
  FILE* file = fopen(url.fileSystemRepresentation, "rb");
  if (!file) {
    if (error) *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
    return nil;
  }
  unsigned char bytes[65537];
  size_t count = fread(bytes, 1, sizeof bytes, file);
  BOOL failed = ferror(file); fclose(file);
  if (failed || count > 65536) { pattern_error(error, @"无法读取图案包，或文件超过 64 KiB。"); return nil; }
  return [NSData dataWithBytes:bytes length:count];
}

BOOL knit_pattern_decode(NSData* data, struct knit_chart* output, NSError** error) {
  if (!output || !data.length || data.length > 65536)
    return pattern_error(error, @"图案包必须是非空、最多 64 KiB 的 JSON 文件。");
  id value = [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
  if (![value isKindOfClass:NSDictionary.class]) return pattern_error(error, @"图案包的内容必须是 JSON 对象。");
  NSDictionary* d = value;
  if (![d[@"kind"] isEqual:@"window-festival-pattern"] || !pattern_number(d[@"version"], 1, 1))
    return pattern_error(error, @"不支持这个文件或图案包版本（需要 version 1）。");
  NSString* title = d[@"title"];
  if (![title isKindOfClass:NSString.class] || !title.length || title.length > 40 ||
      [title lengthOfBytesUsingEncoding:NSUTF8StringEncoding] >= sizeof output->title ||
      [title rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location != NSNotFound ||
      ![title stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].length)
    return pattern_error(error, @"图案名称需要 1–40 个字符，不能包含换行或控制字符。");
  NSArray* palette = d[@"palette"], *grid = d[@"grid"];
  if (![palette isKindOfClass:NSArray.class] || !palette.count || palette.count > 15 ||
      ![grid isKindOfClass:NSArray.class] || grid.count < 4 || grid.count > 14)
    return pattern_error(error, @"图案需要 4–14 格的方形针脚网格，以及 1–15 种线色。");
  struct knit_chart chart = {0};
  uint32_t colors[15];
  if (!pattern_color(d[@"baseColor"], &chart.base_color)) return pattern_error(error, @"底色需要 #RRGGBB 格式。");
  for (NSUInteger i = 0; i < palette.count; i++)
    if (!pattern_color(palette[i], &colors[i])) return pattern_error(error, @"每种线色都需要 #RRGGBB 格式。");
  if (!pattern_number(d[@"spacing"], 0, 3) || !pattern_number(d[@"width"], 2, 60))
    return pattern_error(error, @"间距需要在 0–3 倍之间，边框宽度需要在 2–60 pt 之间。");
  uint32_t pixels[14*14] = {0}; BOOL visible = NO;
  for (NSUInteger y = 0; y < grid.count; y++) {
    id row = grid[y];
    if (![row isKindOfClass:NSString.class] || [row length] != grid.count ||
        [row lengthOfBytesUsingEncoding:NSUTF8StringEncoding] != grid.count)
      return pattern_error(error, @"网格必须是方形，每格使用 . 或 a–o 表示。");
    const char* cells = [row UTF8String];
    for (NSUInteger x = 0; x < grid.count; x++) {
      if (cells[x] == '.') continue;
      int color = cells[x] - 'a';
      if (color < 0 || color >= (int)palette.count) return pattern_error(error, @"网格引用了不存在的线色。");
      pixels[y*grid.count+x] = colors[color]; visible = YES;
    }
  }
  if (!visible) return pattern_error(error, @"图案不能全部为空白针脚。");
  chart.w = chart.h = (int)grid.count;
  chart.px = malloc(grid.count*grid.count*sizeof(uint32_t));
  if (!chart.px) return pattern_error(error, @"内存不足，未加载图案。");
  memcpy(chart.px, pixels, grid.count*grid.count*sizeof(uint32_t));
  snprintf(chart.title, sizeof chart.title, "%s", title.UTF8String);
  chart.spacing = [d[@"spacing"] floatValue]; chart.preferred_width = [d[@"width"] floatValue];
  chart.custom = chart.packaged = chart.upright = chart.solid_corners = chart.sculpted_yarn = chart.defined_yarn = true;
  *output = chart;
  return YES;
}

NSData* knit_pattern_encode(const struct knit_chart* chart, NSError** error) {
  if (!chart || !chart->px || chart->w != chart->h || chart->w < 4 || chart->w > 14) {
    pattern_error(error, @"这个图案不符合 4–14 格的方形图案包格式。"); return nil;
  }
  NSMutableArray* palette = [NSMutableArray array], *grid = [NSMutableArray array];
  uint32_t colors[15]; int count = 0;
  for (int y = 0; y < chart->h; y++) {
    NSMutableString* row = [NSMutableString string];
    for (int x = 0; x < chart->w; x++) {
      uint32_t color = chart->px[y*chart->w+x];
      if ((color >> 24) < 128) { [row appendString:@"."]; continue; }
      color |= 0xff000000u;
      int i = 0; while (i < count && colors[i] != color) i++;
      if (i == count) {
        if (count == 15) { pattern_error(error, @"图案最多可以包含 15 种线色。"); return nil; }
        colors[count++] = color;
        [palette addObject:[NSString stringWithFormat:@"#%06X", color & 0xffffff]];
      }
      [row appendFormat:@"%c", 'a'+i];
    }
    [grid addObject:row];
  }
  NSDictionary* document = @{@"kind": @"window-festival-pattern", @"version": @1,
    @"title": @(chart->title), @"baseColor": [NSString stringWithFormat:@"#%06X", chart->base_color & 0xffffff],
    @"palette": palette, @"grid": grid, @"spacing": @(chart->spacing),
    @"width": @(chart->preferred_width ?: 28)};
  if (![NSJSONSerialization isValidJSONObject:document]) { pattern_error(error, @"配置中含有无效数值。"); return nil; }
  NSData* data = [NSJSONSerialization dataWithJSONObject:document options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:error];
  struct knit_chart verified = {0};
  if (!knit_pattern_decode(data, &verified, error)) return nil;
  free(verified.px);
  return data;
}

NSString* knit_pattern_install(NSData* data, const char* directory, NSError** error) {
  struct knit_chart verified = {0};
  if (!knit_pattern_decode(data, &verified, error)) return nil;
  free(verified.px);
  if (!directory || !*directory) { pattern_error(error, @"图案目录不可用。"); return nil; }
  NSFileManager* files = NSFileManager.defaultManager;
  NSURL* root = [NSURL fileURLWithPath:@(directory) isDirectory:YES];
  if (![files createDirectoryAtURL:root withIntermediateDirectories:YES attributes:nil error:error]) return nil;
  NSString* name = [@"user-" stringByAppendingString:NSUUID.UUID.UUIDString.lowercaseString];
  NSURL* final = [root URLByAppendingPathComponent:[name stringByAppendingString:@".knit.json"]];
  NSURL* staging = [root URLByAppendingPathComponent:[@"." stringByAppendingString:NSUUID.UUID.UUIDString]];
  if (![data writeToURL:staging options:NSDataWritingAtomic error:error]) return nil;
  BOOL installed = [files moveItemAtURL:staging toURL:final error:error];
  if (!installed) [files removeItemAtURL:staging error:nil];
  return installed ? name : nil;
}

NSURL* knit_pattern_trash(const char* directory, NSString* name, NSError** error) {
  if (!directory || !*directory || !name.length || [name hasPrefix:@"."] ||
      [name rangeOfString:@"/"].location != NSNotFound) {
    pattern_error(error, @"图案包路径无效。"); return nil;
  }
  NSURL* root = [NSURL fileURLWithPath:@(directory) isDirectory:YES];
  NSURL* file = [root URLByAppendingPathComponent:[name stringByAppendingString:@".knit.json"]];
  NSNumber* regular = nil, *symlink = nil;
  if (![file getResourceValue:&regular forKey:NSURLIsRegularFileKey error:error] ||
      ![file getResourceValue:&symlink forKey:NSURLIsSymbolicLinkKey error:error]) return nil;
  if (!regular.boolValue || symlink.boolValue) {
    pattern_error(error, @"只能移除本地图案包文件。"); return nil;
  }
  NSURL* trashed = nil;
  return [NSFileManager.defaultManager trashItemAtURL:file resultingItemURL:&trashed error:error] ? trashed : nil;
}

void knit_patterns_load(const char* directory) {
  if (!directory || !*directory) return;
  @autoreleasepool {
    NSURL* root = [NSURL fileURLWithPath:@(directory) isDirectory:YES];
    NSArray<NSURL*>* files = [NSFileManager.defaultManager contentsOfDirectoryAtURL:root
        includingPropertiesForKeys:@[NSURLIsRegularFileKey, NSURLIsSymbolicLinkKey]
        options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];
    files = [files sortedArrayUsingComparator:^NSComparisonResult(NSURL* a, NSURL* b) { return [a.lastPathComponent compare:b.lastPathComponent]; }];
    for (NSURL* url in files) {
      if (g_chart_count >= KNIT_CHART_MAX) break;
      NSString* filename = url.lastPathComponent;
      if (![filename hasSuffix:@".knit.json"]) continue;
      NSNumber* regular = nil, *symlink = nil;
      [url getResourceValue:&regular forKey:NSURLIsRegularFileKey error:nil];
      [url getResourceValue:&symlink forKey:NSURLIsSymbolicLinkKey error:nil];
      if (!regular.boolValue || symlink.boolValue) continue;
      NSString* name = [filename substringToIndex:filename.length-10];
      if (!name.length || [name lengthOfBytesUsingEncoding:NSUTF8StringEncoding] >= sizeof g_charts[0].name || knit_chart_index(name.UTF8String) >= 0) continue;
      struct knit_chart chart = {0};
      if (!knit_pattern_decode(knit_pattern_read(url, nil), &chart, nil)) continue;
      snprintf(chart.name, sizeof chart.name, "%s", name.UTF8String);
      g_charts[g_chart_count++] = chart;
    }
  }
}
