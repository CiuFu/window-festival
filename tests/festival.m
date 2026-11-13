// Real colourwork renderer and parser; no windows or user preferences.
#define main original_render_main
#include "render.c"
#undef main
#include "../src/parse.h"

static const char* motifs[] = {
  "festival-plum", "festival-lantern", "festival-spring", "festival-daisy", "festival-bamboo",
  "festival-tulip", "festival-cloud", "festival-diamond", "festival-persimmon"
};
enum { MOTIF_COUNT = sizeof motifs / sizeof motifs[0] };

static void festival_preview(const char* path) {
  CGContextRef c = canvas(1120, 1080, 2);
  CGContextSetRGBFillColor(c, .97, .95, .91, 1);
  CGContextFillRect(c, CGRectMake(0, 0, 1120, 1080));
  text_at(c, 40, 46, "Window Festival · nine knitted patterns", 26);
  text_at(c, 40, 73, "28 pt borders · more space between motifs · enlarged yarn details below", 14);
  const char* titles[] = {"梅花 · Plum Blossom", "灯笼 · Lantern", "春 · Spring",
    "雏菊 · Daisy", "竹叶 · Bamboo", "郁金香 · Tulip", "祥云 · Cloud", "菱花 · Diamond", "柿子 · Persimmon"};
  for (int i = 0; i < MOTIF_COUNT; i++) {
    float x = 52 + (i % 3) * 368, y = 136 + (i / 3) * 328;
    CGRect win = CGRectMake(x, y, 280, 136);
    CGContextSaveGState(c);
    CGContextTranslateCTM(c, 0, 2 * CGRectGetMidY(win));
    CGContextScaleCTM(c, 1, -1); // Match the native window's yarn orientation.
    knit_draw(c, win, 10, 28, 0xff123456, knit_chart_index(motifs[i]), 0, 1);
    CGContextRestoreGState(c);
    CGPathRef p = CGPathCreateWithRoundedRect(win, 10, 10, NULL);
    CGContextSetRGBFillColor(c, .998, .992, .98, 1);
    CGContextAddPath(c, p); CGContextFillPath(c); CFRelease(p);
    text_at(c, x + 25, y + 76, titles[i], 18);
    CGContextSaveGState(c);
    CGContextClipToRect(c, CGRectMake(x - 18, y + 192, 316, 40));
    CGRect detail = CGRectMake(x - 18, y + 232, 316, 80);
    CGContextTranslateCTM(c, 0, 2 * CGRectGetMidY(detail));
    CGContextScaleCTM(c, 1, -1);
    knit_draw(c, detail, 0, 40, 0xff123456, knit_chart_index(motifs[i]), 0, 0);
    CGContextRestoreGState(c);
  }
  write_image(c, path);
  CGContextRelease(c);
}

static void check_motifs(void) {
  struct settings settings = {.border_width = 28};
  struct knit_gauge saved = g_knit;
  for (int i = 0; i < MOTIF_COUNT; i++) {
    int chart = knit_chart_index(motifs[i]);
    assert(chart >= 0 && g_charts[chart].upright && g_charts[chart].base_color);
    assert(g_charts[chart].w == g_charts[chart].h && g_charts[chart].sculpted_yarn);
    char arg[64]; snprintf(arg, sizeof arg, "chart=%s", motifs[i]);
    char* args[] = {arg};
    assert(parse_settings(&settings, 1, args) & BORDER_UPDATE_MASK_ALL);
    assert(!g_knit_pattern_by_app && g_chart_active == chart);
    assert(memcmp(&saved, &g_knit, sizeof saved) == 0);
    for (int scale = 1; scale <= 2; scale++) {
      for (int width = 12; width <= 28; width += 8) {
        CGContextRef a = canvas(240, 240, scale), b = canvas(240, 240, scale);
        CGRect win = CGRectMake(40, 40, 160, 160);
        knit_draw(a, win, 10, width, 0xff123456, chart, 0, 0);
        knit_draw(b, win, 10, width, 0xffabcdef, chart, 0, 0);
        // Own palette is independent of the window's application colour.
        for (int y = 0; y < 240*scale; y++) for (int x = 0; x < 240*scale; x++) {
          assert(pixel(a,x,y) == pixel(b,x,y));
          if (x < (40-width)*scale || x >= (200+width)*scale ||
              y < (40-width)*scale || y >= (200+width)*scale)
            assert((pixel(a,x,y) >> 24) == 0);
        }
        assert(pixel(a,120*scale,120*scale) == 0);
        // Corresponding whole motif cells on every edge have the same orientation.
        // Square window and even dimensions keep origins aligned to device pixels.
        float gap = width * .75f;
        int repeats = (140 + gap) / (width + gap);
        float start = (240 - (repeats * (width + gap) - gap)) / 2;
        for (int y = 1; y < width-1; y++) for (int x = 1; x < width-1; x++) {
          uint32_t top = pixel(a,(start+x)*scale,(40-width+y)*scale);
          assert(top == pixel(a,(start+x)*scale,(200+y)*scale));
          uint32_t left = pixel(a,(40-width+x)*scale,(start+y)*scale);
          assert(left == pixel(a,(200+x)*scale,(start+y)*scale));
          // At 1×, half-point placement has a different sampling phase on vertical edges.
          if (scale == 2 || start == floorf(start)) assert(top == left);
        }
        CGContextRelease(a); CGContextRelease(b);
      }
    }
  }
  char* old = "theme=spring-festival";
  assert(parse_settings(&settings,1,&old) & BORDER_UPDATE_MASK_ALL);
  assert(g_chart_active == knit_chart_index("festival-lantern"));
  old = "theme=sweaters";
  assert(parse_settings(&settings,1,&old) & BORDER_UPDATE_MASK_ALL);
  assert(g_knit_pattern_by_app);
  // The long upper stroke of 春 must remain above the narrow 日 strokes.
  for (int native = 0; native <= 1; native++) {
    CGContextRef glyph = canvas(336, 280, 1);
    if (native) {
      CGContextTranslateCTM(glyph, 0, 280);
      CGContextScaleCTM(glyph, 1, -1);
    }
    knit_draw(glyph, CGRectMake(56,native ? 56 : 112,224,112), 0, 56, 0,
              knit_chart_index("festival-spring"), 0, 0);
    int gold[2] = {0};
    for (int row = 0; row < 2; row++)
      for (int y = 56 + (row ? 11 : 2)*4; y < 56 + (row ? 12 : 3)*4; y++)
        for (int x = 91; x < 147; x++) {
          uint32_t p = pixel(glyph,x,y);
          if (((p>>8)&255) > .55f*((p>>16)&255)) gold[row]++;
        }
    assert(gold[0] > 2*gold[1]);
    // The 42 pt interval between 56 pt motifs contains only the red base yarn.
    for (int y = 56; y < 112; y++) for (int x = 154; x < 182; x++) {
      uint32_t p = pixel(glyph,x,y);
      assert(((p>>8)&255) < .55f*((p>>16)&255));
    }
    CGContextRelease(glyph);
  }
  CGContextRef small = canvas(96,96,2);
  knit_draw(small,CGRectMake(40,40,16,16),10,28,0,
            knit_chart_index("festival-spring"),0,0);
  for (int y = 0; y < 192; y++) for (int x = 0; x < 192; x++) {
    uint32_t p = pixel(small,x,y);
    if (p >> 24) assert(((p>>8)&255) < .55f*((p>>16)&255));
  }
  CGContextRelease(small);
  puts("PASS: nine knitted motifs; spaced repeats; four upright edges; 1×/2× bounds; short edges; legacy CLI aliases");
}

int main(int argc, char** argv) {
  knit_charts_load(NULL);
  check_motifs();
  if (argc > 1) festival_preview(argv[1]);
  knit_flush_cache();
  return 0;
}
