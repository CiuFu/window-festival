#define main original_render_main
#include "render.c"
#undef main
#import "misc/patterns.h"
#include <unistd.h>

static NSData* json(NSDictionary* d) { return [NSJSONSerialization dataWithJSONObject:d options:0 error:nil]; }
static void reject(NSDictionary* d) {
  struct knit_chart output = {0}; NSError* error = nil;
  assert(!knit_pattern_decode(json(d),&output,&error) && error && !output.px);
}
int main(int argc, char** argv) {
  @autoreleasepool {
    knit_charts_load(NULL);
    for (int i=0;i<g_chart_count;i++) if (g_charts[i].upright) {
      struct knit_chart input = g_charts[i], result = {0};
      snprintf(input.title,sizeof input.title,"%s",input.name);
      NSError* error = nil; NSData* data = knit_pattern_encode(&input,&error);
      assert(data && !error && knit_pattern_decode(data,&result,&error));
      assert(result.w==input.w && result.h==input.h && result.base_color==input.base_color);
      assert(result.upright && result.packaged && result.spacing==input.spacing && result.preferred_width==28);
      assert(!memcmp(result.px,input.px,(size_t)input.w*input.h*4)); free(result.px);
    }
    struct knit_chart daisy = g_charts[knit_chart_index("festival-daisy")];
    snprintf(daisy.title,sizeof daisy.title,"晨雾雏菊"); daisy.base_color=0xff465f67; daisy.spacing=1.25; daisy.preferred_width=28;
    NSData* example = knit_pattern_encode(&daisy,nil); assert(example);
    NSDictionary* valid = [NSJSONSerialization JSONObjectWithData:example options:0 error:nil];
    for (NSString* key in @[@"kind",@"version",@"title",@"baseColor",@"palette",@"grid",@"spacing",@"width"]) {
      NSMutableDictionary* d = valid.mutableCopy; [d removeObjectForKey:key]; reject(d);
      d = valid.mutableCopy; d[key]=NSNull.null; reject(d);
    }
    NSArray* invalid = @[
      @{@"version":@YES}, @{@"version":@2}, @{@"title":@""}, @{@"title":@"bad\nname"},
      @{@"baseColor":@"#11223Z"}, @{@"palette":@[]}, @{@"palette":@[@"#ff00"]},
      @{@"grid":@[@"a..."]}, @{@"grid":@[@"....",@"....",@"....",@"...."]},
      @{@"grid":@[@"z...",@"....",@"....",@"...."]},
      @{@"grid":@[@"a...",@".....",@"....",@"...."]},
      @{@"spacing":@YES}, @{@"spacing":@(-.1)}, @{@"spacing":@3.1}, @{@"spacing":@"1"},
      @{@"width":@1}, @{@"width":@61}];
    for (NSDictionary* change in invalid) { NSMutableDictionary* d=valid.mutableCopy; [d addEntriesFromDictionary:change]; reject(d); }
    struct knit_chart invalidOutput={0};
    assert(!knit_pattern_decode([NSMutableData dataWithLength:65537],&invalidOutput,nil));
    assert(!knit_pattern_decode([@"not JSON" dataUsingEncoding:NSUTF8StringEncoding],&invalidOutput,nil));
    char temp[]="/tmp/window-festival-patterns.XXXXXX"; assert(mkdtemp(temp));
    NSString* first=knit_pattern_install(example,temp,nil), *second=knit_pattern_install(example,temp,nil);
    assert(first && second && ![first isEqual:second]);
    NSString* firstPath=[@(temp) stringByAppendingPathComponent:[first stringByAppendingString:@".knit.json"]];
    assert([[NSData dataWithContentsOfFile:firstPath] isEqual:example]);
    assert(!knit_pattern_install([@"invalid" dataUsingEncoding:NSUTF8StringEncoding],temp,nil));
    assert([NSFileManager.defaultManager contentsOfDirectoryAtPath:@(temp) error:nil].count==2);
    // Invalid files, symlinks and built-in names cannot replace existing charts.
    [example writeToFile:[@(temp) stringByAppendingPathComponent:@"festival-daisy.knit.json"] atomically:YES];
    [@"invalid" writeToFile:[@(temp) stringByAppendingPathComponent:@"broken.knit.json"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    assert(symlink(firstPath.fileSystemRepresentation,[[@(temp) stringByAppendingPathComponent:@"linked.knit.json"] fileSystemRepresentation])==0);
    NSString* oversized=[@(temp) stringByAppendingPathComponent:@"huge.knit.json"];
    assert([[NSMutableData dataWithLength:65537] writeToFile:oversized atomically:YES]);
    assert(!knit_pattern_read([NSURL fileURLWithPath:oversized],nil));
    assert(knit_charts_load(temp)==58);
    assert(g_charts[knit_chart_index("festival-daisy")].base_color!=daisy.base_color);
    assert(knit_pattern_select(first.UTF8String));
    assert(knit_charts_load(temp)==58 && !strcmp(g_charts[g_chart_active].name,first.UTF8String));
    assert(!strcmp(g_charts[g_chart_active].title,"晨雾雏菊"));
    assert([NSFileManager.defaultManager removeItemAtPath:@(temp) error:nil]);
    knit_charts_load(NULL); knit_flush_cache();
    int index=knit_chart_index("festival-spring");
    const float widths[]={14.3f,28};
    for (int i=0;i<2;i++) {
      struct knit_chart draft=g_charts[index]; float width=widths[i];
      CGContextRef before=canvas(240,240,2), preview=canvas(240,240,2), after=canvas(240,240,2);
      CGRect win=CGRectMake(40,40,160,160);
      knit_draw(before,win,10,width,0,index,0,0);
      const void* identity=knit_tile_identity(width,draft.base_color,index); assert(identity);
      knit_draw_pattern_preview(preview,win,10,width,&draft);
      for(int y=0;y<480;y++) for(int x=0;x<480;x++) assert(pixel(before,x,y)==pixel(preview,x,y));
      draft.base_color=0xff208060; draft.spacing=2.5;
      knit_draw_pattern_preview(preview,win,10,width,&draft);
      assert(knit_tile_identity(width,g_charts[index].base_color,index)==identity);
      knit_draw(after,win,10,width,0,index,0,0);
      for(int y=0;y<480;y++) for(int x=0;x<480;x++) assert(pixel(before,x,y)==pixel(after,x,y));
      CGContextRelease(before); CGContextRelease(preview); CGContextRelease(after);
    }
    if(argc>1) assert([example writeToFile:@(argv[1]) options:NSDataWritingAtomic error:nil]);
    knit_flush_cache();
    puts("PASS: nine package round-trips; strict validation; duplicate-safe imports; reload by name; isolated live previews");
  }
  return 0;
}
