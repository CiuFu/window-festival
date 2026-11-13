#import <Cocoa/Cocoa.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <QuartzCore/QuartzCore.h>
#import "misc/library.h"
#import "misc/patterns.h"
#include "misc/knit.h"
#include "misc/apps.h"
#include "misc/width_presets.h"

static NSString* library_title(const struct knit_chart* chart) {
  if (chart->title[0]) return @(chart->title);
  NSDictionary* names = @{@"festival-plum": @"梅花", @"festival-lantern": @"灯笼", @"festival-spring": @"春",
    @"festival-daisy": @"雏菊", @"festival-bamboo": @"竹叶", @"festival-tulip": @"郁金香",
    @"festival-cloud": @"祥云", @"festival-diamond": @"菱花", @"festival-persimmon": @"柿子"};
  return names[@(chart->name)] ?: @(chart->name);
}
static NSColor* library_color(uint32_t c) {
  return [NSColor colorWithSRGBRed:((c>>16)&255)/255.0 green:((c>>8)&255)/255.0 blue:(c&255)/255.0 alpha:1];
}
static uint32_t library_hex(NSColor* color) {
  NSColor* c = [color colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
  return 0xff000000u | ((uint32_t)lround(c.redComponent*255)<<16) |
      ((uint32_t)lround(c.greenComponent*255)<<8) | (uint32_t)lround(c.blueComponent*255);
}
static NSTextField* library_label(NSString* text, NSRect frame, CGFloat size) {
  NSTextField* label = [NSTextField labelWithString:text]; label.frame = frame;
  label.font = [NSFont systemFontOfSize:size]; return label;
}
static NSImage* library_image(const struct knit_chart* chart, float width) {
  CGColorSpaceRef colors = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
  CGContextRef c = CGBitmapContextCreate(NULL,600,380,8,0,colors,kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host);
  CGColorSpaceRelease(colors); if (!c) return nil;
  CGContextScaleCTM(c,2,2);
  CGRect win = CGRectMake(width+8,width+8,300-2*(width+8),190-2*(width+8));
  knit_draw_pattern_preview(c,win,9,width,chart);
  CGPathRef path = CGPathCreateWithRoundedRect(win,9,9,NULL);
  CGContextSetRGBFillColor(c,.98,.975,.96,1); CGContextAddPath(c,path); CGContextFillPath(c); CFRelease(path);
  for (int i=0;i<3;i++) {
    CGContextSetRGBFillColor(c,.76,.75,.72,1);
    CGContextFillEllipseInRect(c,CGRectMake(win.origin.x+10+i*10,CGRectGetMaxY(win)-15,5,5));
  }
  CGImageRef image = CGBitmapContextCreateImage(c);
  NSImage* result = image ? [[NSImage alloc] initWithCGImage:image size:NSMakeSize(300,190)] : nil;
  if (image) CGImageRelease(image); CGContextRelease(c); return result;
}

static void library_choice(NSPopUpButton* popup, NSString* title, float value) {
  [popup addItemWithTitle:title]; popup.lastItem.representedObject = @(value);
}

static void library_select_value(NSPopUpButton* popup, float value, NSUInteger presetCount, NSString* custom) {
  if (popup.numberOfItems > presetCount) [popup removeItemAtIndex:presetCount];
  for (NSMenuItem* item in popup.itemArray) if ([item.representedObject floatValue] == value) {
    [popup selectItem:item]; return;
  }
  library_choice(popup, custom, value); [popup selectItem:popup.lastItem];
}

@interface KnitPatternCard : NSCollectionViewItem
@property(strong) NSTextField* kind;
@end
@implementation KnitPatternCard
- (void)loadView {
  self.view = [[NSView alloc] initWithFrame:NSMakeRect(0,0,184,160)]; self.view.wantsLayer = YES;
  self.view.layer.cornerRadius = 10; self.view.layer.borderWidth = 1;
  NSImageView* image = [[NSImageView alloc] initWithFrame:NSMakeRect(8,45,168,106)];
  image.imageScaling = NSImageScaleProportionallyUpOrDown; [self.view addSubview:image]; self.imageView = image;
  NSTextField* title = library_label(@"",NSMakeRect(12,24,160,20),14); [self.view addSubview:title]; self.textField = title;
  self.kind = library_label(@"",NSMakeRect(12,6,160,16),11); self.kind.textColor = NSColor.secondaryLabelColor; [self.view addSubview:self.kind];
  [self setSelected:NO];
}
- (void)setSelected:(BOOL)selected {
  [super setSelected:selected];
  self.view.layer.borderColor = (selected ? NSColor.controlAccentColor : NSColor.separatorColor).CGColor;
  self.view.layer.borderWidth = selected ? 2 : 1;
  self.view.layer.backgroundColor = NSColor.controlBackgroundColor.CGColor;
}
@end

@interface KnitLibraryPanel : NSView
@end
@implementation KnitLibraryPanel
- (BOOL)isFlipped { return YES; }
@end

@interface KnitEditorColorWell : NSColorWell
@property(copy) NSString* confirmTitle;
@property(strong) NSButton* confirmButton;
@property(strong) NSColor* colorBeforePicking;
@property(readonly) NSColor* committedColor;
- (void)applyPanelColor:(id)sender;
@end

@implementation KnitEditorColorWell
- (NSColor*)committedColor {
  return self.colorBeforePicking ?: self.color;
}
- (void)activate:(BOOL)exclusive {
  if (!self.active) self.colorBeforePicking = self.color;
  [super activate:exclusive];
  NSColorPanel* panel = NSColorPanel.sharedColorPanel;
  self.confirmButton = [NSButton buttonWithTitle:self.confirmTitle target:self action:@selector(applyPanelColor:)];
  self.confirmButton.frame = NSMakeRect(8,4,150,28);
  NSView* footer = [[NSView alloc] initWithFrame:NSMakeRect(0,0,166,36)];
  [footer addSubview:self.confirmButton];
  panel.accessoryView = footer;
  NSScreen* screen = self.window.screen ?: NSScreen.mainScreen;
  if (!screen || !self.window) return;
  NSRect visible = screen.visibleFrame;
  NSRect frame = panel.frame;
  CGFloat beside = NSMaxX(self.window.frame) + 12;
  frame.origin.x = MIN(beside, NSMaxX(visible) - frame.size.width);
  frame.origin.x = MAX(frame.origin.x, NSMinX(visible));
  frame.origin.y = MAX(NSMinY(visible), MIN(NSMaxY(self.window.frame), NSMaxY(visible)) - frame.size.height);
  [panel setFrameOrigin:frame.origin];
}
- (void)takeColorFrom:(id)sender {
  // Apply the panel's color only when the user confirms the current action.
  if (sender != NSColorPanel.sharedColorPanel || !self.active) [super takeColorFrom:sender];
}
- (void)applyPanelColor:(id)sender {
  NSColorPanel* panel = NSColorPanel.sharedColorPanel;
  NSColor* selected = panel.color;
  [panel orderOut:nil];
  [self deactivate];
  self.color = selected;
  [self sendAction:self.action to:self.target];
}
- (void)deactivate {
  if (self.confirmButton.superview == NSColorPanel.sharedColorPanel.accessoryView && self.confirmButton)
    NSColorPanel.sharedColorPanel.accessoryView = nil;
  self.confirmButton = nil;
  NSColor* previous = self.colorBeforePicking;
  self.colorBeforePicking = nil;
  [super deactivate];
  if (previous) self.color = previous;
}
@end

@interface KnitGridEditor : NSViewController {
@public
  struct knit_chart pattern;
  uint32_t pixels[14*14];
}
@property(strong) NSImageView* preview;
@property(strong) KnitEditorColorWell* brush;
@property(strong) KnitEditorColorWell* background;
@property(strong) NSPopUpButton* previewWidth;
@property(strong) NSButton* brushSwatch;
@property BOOL usesGround;
@property(strong) NSScrollView* patternScroll;
@property(strong) NSArray<NSNumber*>* patternColors;
@property(strong) NSTextField* hint;
@property(strong) NSMutableArray<NSButton*>* cells;
@property(strong) NSUndoManager* history;
@property(strong) NSButton* undoButton;
@property(strong) NSButton* redoButton;
@property(strong) NSMutableArray<NSNumber*>* palette;
@property(strong) NSUserDefaults* paletteDefaults;
@property(strong) NSScrollView* paletteScroll;
@property(strong) NSView* swatches;
@property(strong) NSButton* manage;
@property(strong) NSButton* moveLeft;
@property(strong) NSButton* moveRight;
@property(strong) NSButton* removeColor;
@end

static NSString* const grid_palette_key = @"gridEditorPalette";

@implementation KnitGridEditor
- (void)previewGrid {
  self.preview.image = library_image(&pattern,[self.previewWidth.selectedItem.representedObject floatValue]);
}
- (void)refreshStitch:(NSUInteger)index {
  self.cells[index].layer.backgroundColor = library_color(pixels[index] ?: pattern.base_color).CGColor;
}
- (void)refreshHistoryButtons {
  self.undoButton.enabled = self.history.canUndo;
  self.redoButton.enabled = self.history.canRedo;
}
- (void)undoEdit:(id)sender {
  [self.history undo];
  [self refreshHistoryButtons];
}
- (void)redoEdit:(id)sender {
  [self.history redo];
  [self refreshHistoryButtons];
}
- (void)setStitch:(NSUInteger)index color:(uint32_t)color {
  uint32_t previous = pixels[index];
  if (color == previous) return;
  [self.history registerUndoWithTarget:self handler:^(KnitGridEditor* editor) {
    [editor setStitch:index color:previous];
  }];
  pixels[index] = color;
  [self refreshStitch:index];
  [self refreshPatternColors];
  [self previewGrid];
}
- (void)paint:(NSButton*)cell {
  NSUInteger index = cell.tag;
  if (NSApp.currentEvent.modifierFlags & NSEventModifierFlagOption) {
    [self selectPaintColor:pixels[index]];
    return;
  }
  uint32_t color = self.usesGround ? 0 : library_hex(self.brush.committedColor);
  if (pixels[index] == color) return;
  [self.history beginUndoGrouping];
  [self setStitch:index color:color];
  [self.history endUndoGrouping];
  [self refreshHistoryButtons];
}
- (void)setGroundColor:(uint32_t)color {
  uint32_t previous = pattern.base_color;
  if (color == previous) return;
  [self.history registerUndoWithTarget:self handler:^(KnitGridEditor* editor) {
    [editor setGroundColor:previous];
  }];
  pattern.base_color = color;
  self.background.color = library_color(color);
  [self refreshPaletteSelection];
  for (NSUInteger i=0; i<self.cells.count; i++) if (!pixels[i]) [self refreshStitch:i];
  [self previewGrid];
}
- (void)changeGround:(id)sender {
  if (self.background.active) return;
  [self.history beginUndoGrouping];
  [self setGroundColor:library_hex(self.background.color)];
  [self.history endUndoGrouping];
  [self refreshHistoryButtons];
}
- (void)changePreviewWidth:(id)sender { [self previewGrid]; }
- (NSUInteger)brushIndex {
  return [self.palette indexOfObject:@(library_hex(self.brush.committedColor))];
}
- (void)markSwatch:(NSButton*)swatch selected:(BOOL)selected {
  swatch.layer.borderWidth = selected ? 3 : 1;
  swatch.layer.borderColor = (selected ? NSColor.controlAccentColor : NSColor.separatorColor).CGColor;
  [swatch setAccessibilityValue:selected ? @"已选中" : @""];
}
- (void)refreshPaletteSelection {
  uint32_t brushColor = self.usesGround ? pattern.base_color : library_hex(self.brush.committedColor);
  self.brushSwatch.layer.backgroundColor = library_color(brushColor).CGColor;
  self.brushSwatch.toolTip = self.usesGround ? @"当前使用底色，点击可换色" : @"点击更换画笔颜色";
  [self.brushSwatch setAccessibilityValue:self.usesGround ? @"底色" : [NSString stringWithFormat:@"#%06X",brushColor & 0xffffff]];
  NSUInteger selected = self.usesGround ? NSNotFound : [self brushIndex];
  for (NSButton* swatch in self.swatches.subviews)
    [self markSwatch:swatch selected:(NSUInteger)swatch.tag == selected];
  for (NSButton* swatch in self.patternScroll.documentView.subviews) {
    uint32_t color = (uint32_t)swatch.tag;
    if (!color) swatch.layer.backgroundColor = library_color(pattern.base_color).CGColor;
    [self markSwatch:swatch selected:self.usesGround ? !color : color == brushColor];
  }
  self.moveLeft.enabled = selected != NSNotFound && selected > 0;
  self.moveRight.enabled = selected != NSNotFound && selected+1 < self.palette.count;
  self.removeColor.enabled = selected != NSNotFound;
}
- (void)chooseBrush:(id)sender {
  if (self.brush.active) return;
  self.usesGround = NO;
  [self refreshPaletteSelection];
}
- (void)selectPaintColor:(uint32_t)color {
  if (self.brush.active || self.background.active) [NSColorPanel.sharedColorPanel orderOut:nil];
  [self.background deactivate];
  [self.brush deactivate];
  self.brush.color = library_color(color ?: pattern.base_color);
  self.usesGround = color == 0;
  [self refreshPaletteSelection];
}
- (void)chooseSwatch:(NSButton*)sender {
  [self selectPaintColor:self.palette[sender.tag].unsignedIntValue];
}
- (void)choosePatternSwatch:(NSButton*)sender {
  [self selectPaintColor:(uint32_t)sender.tag];
}
- (void)openBrushPicker:(id)sender {
  [self.brush deactivate];
  if (self.usesGround) self.brush.color = library_color(pattern.base_color);
  [self.brush activate:YES];
  [NSColorPanel.sharedColorPanel orderFront:nil];
}
- (void)openPalettePicker:(id)sender {
  [self openBrushPicker:nil];
  self.brush.confirmButton.title = @"添加到常用色";
  self.brush.confirmButton.target = self;
  self.brush.confirmButton.action = @selector(confirmPaletteColor:);
}
- (void)confirmPaletteColor:(id)sender {
  [self.brush applyPanelColor:nil];
  [self addBrushColor:nil];
}
- (NSButton*)colorSwatch:(uint32_t)color action:(SEL)action {
  NSButton* swatch = [NSButton buttonWithTitle:@"" target:self action:action];
  swatch.frame = NSMakeRect(0,0,24,24);
  swatch.bordered = NO;
  swatch.wantsLayer = YES;
  swatch.layer.cornerRadius = 4;
  swatch.layer.backgroundColor = library_color(color ?: pattern.base_color).CGColor;
  swatch.toolTip = color ? [NSString stringWithFormat:@"#%06X",color & 0xffffff] : @"底色";
  [swatch setAccessibilityLabel:swatch.toolTip];
  [self markSwatch:swatch selected:NO];
  return swatch;
}
- (void)refreshPatternColors {
  NSMutableOrderedSet<NSNumber*>* used = [NSMutableOrderedSet orderedSetWithObject:@0];
  for (int i=0; i<pattern.w*pattern.h; i++) if (pixels[i]) [used addObject:@(pixels[i])];
  NSArray<NSNumber*>* colors = used.array;
  if (![self.patternColors isEqualToArray:colors]) {
    self.patternColors = colors;
    NSView* row = self.patternScroll.documentView;
    for (NSView* swatch in row.subviews.copy) [swatch removeFromSuperview];
    row.frame = NSMakeRect(0,0,MAX(self.patternScroll.contentSize.width,colors.count*29),26);
    [colors enumerateObjectsUsingBlock:^(NSNumber* entry, NSUInteger index, BOOL* stop) {
      NSButton* swatch = [self colorSwatch:entry.unsignedIntValue action:@selector(choosePatternSwatch:)];
      swatch.tag = entry.unsignedIntValue;
      [swatch setFrameOrigin:NSMakePoint(index*29+1,1)];
      [row addSubview:swatch];
    }];
  }
  [self refreshPaletteSelection];
}
- (void)rebuildPalette {
  for (NSView* swatch in self.swatches.subviews.copy) [swatch removeFromSuperview];
  self.swatches.frame = NSMakeRect(0,0,MAX(self.paletteScroll.contentSize.width,self.palette.count*29),26);
  [self.palette enumerateObjectsUsingBlock:^(NSNumber* entry, NSUInteger index, BOOL* stop) {
    NSButton* swatch = [self colorSwatch:entry.unsignedIntValue action:@selector(chooseSwatch:)];
    swatch.tag = index;
    [swatch setFrameOrigin:NSMakePoint(index*29+1,1)];
    [self.swatches addSubview:swatch];
  }];
  [self refreshPaletteSelection];
}
- (void)storePalette {
  [self.paletteDefaults setObject:self.palette.copy forKey:grid_palette_key];
  [self rebuildPalette];
}
- (void)addBrushColor:(id)sender {
  NSNumber* color = @(library_hex(self.brush.committedColor));
  if (![self.palette containsObject:color]) {
    [self.palette addObject:color];
    [self storePalette];
  }
  NSUInteger index = [self brushIndex];
  [self.swatches scrollRectToVisible:NSMakeRect(index*29,0,26,26)];
}
- (void)managePalette:(id)sender {
  BOOL managing = self.manage.state == NSControlStateValueOn;
  self.manage.title = managing ? @"完成管理" : @"管理";
  self.moveLeft.hidden = self.moveRight.hidden = self.removeColor.hidden = !managing;
  [self refreshPaletteSelection];
}
- (void)moveSwatch:(NSButton*)sender {
  NSUInteger index = [self brushIndex];
  if (index == NSNotFound) return;
  NSInteger next = (NSInteger)index + sender.tag;
  if (next < 0 || next >= (NSInteger)self.palette.count) return;
  [self.palette exchangeObjectAtIndex:index withObjectAtIndex:next];
  [self storePalette];
  [self.swatches scrollRectToVisible:NSMakeRect(next*29,0,26,26)];
}
- (void)removeSwatch:(id)sender {
  NSUInteger index = [self brushIndex];
  if (index == NSNotFound) return;
  [self.palette removeObjectAtIndex:index];
  [self storePalette];
}
- (void)loadView {
  NSView* view = [[NSView alloc] initWithFrame:NSMakeRect(0,0,690,514)];
  self.view = view;
  self.history = [NSUndoManager new];
  self.history.groupsByEvent = NO;
  self.history.levelsOfUndo = 200;
  [view addSubview:library_label(@"针脚工作台",NSMakeRect(24,471,642,26),20)];
  [view addSubview:library_label(@"点击画笔色块换色，按住 ⌥ 点击格子可取色。",NSMakeRect(24,438,642,22),13)];
  self.cells = [NSMutableArray array];
  CGFloat cell = 304.0 / pattern.w;
  for (int y=0;y<pattern.h;y++) for (int x=0;x<pattern.w;x++) {
    int i = y*pattern.w+x;
    NSButton* stitch = [NSButton buttonWithTitle:@"" target:self action:@selector(paint:)];
    stitch.frame = NSMakeRect(24+x*cell,426-(y+1)*cell,cell-1,cell-1);
    stitch.tag = i; stitch.bordered = NO; stitch.wantsLayer = YES;
    [stitch setAccessibilityLabel:[NSString stringWithFormat:@"第 %d 行，第 %d 列",y+1,x+1]];
    [self.cells addObject:stitch]; [view addSubview:stitch];
    [self refreshStitch:i];
  }
  self.preview = [[NSImageView alloc] initWithFrame:NSMakeRect(348,234,318,194)];
  self.preview.imageScaling = NSImageScaleProportionallyUpOrDown;
  [view addSubview:self.preview];
  [view addSubview:library_label(@"底色",NSMakeRect(348,198,70,22),13)];
  self.background = [[KnitEditorColorWell alloc] initWithFrame:NSMakeRect(428,196,46,25)];
  self.background.color = library_color(pattern.base_color);
  self.background.confirmTitle = @"应用底色";
  self.background.target = self; self.background.action = @selector(changeGround:);
  [self.background setAccessibilityLabel:@"底色"]; [view addSubview:self.background];

  [view addSubview:library_label(@"宽度预览",NSMakeRect(348,164,76,22),13)];
  self.previewWidth = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(428,162,238,25) pullsDown:NO];
  NSUInteger presetCount = sizeof knit_width_presets / sizeof knit_width_presets[0];
  for (NSUInteger i=0; i<presetCount; i++) {
    float width = knit_width_presets[i].value;
    library_choice(self.previewWidth,[NSString stringWithFormat:@"%s · %g pt",knit_width_presets[i].name,width],width);
  }
  library_select_value(self.previewWidth,pattern.preferred_width,presetCount,
      [NSString stringWithFormat:@"自定义 · %g pt",pattern.preferred_width]);
  self.previewWidth.target = self; self.previewWidth.action = @selector(changePreviewWidth:);
  [self.previewWidth setAccessibilityLabel:@"宽度预览"]; [view addSubview:self.previewWidth];

  [view addSubview:library_label(@"常用线色",NSMakeRect(348,128,76,22),13)];
  NSButton* add = [NSButton buttonWithTitle:@"＋ 添加颜色…" target:self action:@selector(openPalettePicker:)];
  add.frame = NSMakeRect(465,126,117,26); [view addSubview:add];
  self.manage = [NSButton buttonWithTitle:@"管理" target:self action:@selector(managePalette:)];
  self.manage.buttonType = NSButtonTypePushOnPushOff;
  self.manage.frame = NSMakeRect(587,126,79,26); [view addSubview:self.manage];
  self.paletteScroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(347,94,319,28)];
  self.paletteScroll.drawsBackground = NO;
  self.paletteScroll.hasHorizontalScroller = YES;
  self.paletteScroll.scrollerStyle = NSScrollerStyleOverlay;
  self.swatches = [[NSView alloc] initWithFrame:NSMakeRect(0,0,319,26)];
  self.paletteScroll.documentView = self.swatches;
  [view addSubview:self.paletteScroll];
  self.moveLeft = [NSButton buttonWithTitle:@"← 左移" target:self action:@selector(moveSwatch:)];
  self.moveRight = [NSButton buttonWithTitle:@"右移 →" target:self action:@selector(moveSwatch:)];
  self.removeColor = [NSButton buttonWithTitle:@"删除色块" target:self action:@selector(removeSwatch:)];
  self.moveLeft.tag = -1; self.moveRight.tag = 1;
  self.moveLeft.frame = NSMakeRect(348,56,76,26);
  self.moveRight.frame = NSMakeRect(428,56,76,26);
  self.removeColor.frame = NSMakeRect(508,56,90,26);
  for (NSButton* button in @[self.moveLeft,self.moveRight,self.removeColor]) {
    button.hidden = YES; [view addSubview:button];
  }

  NSTextField* patternLabel = library_label(@"图案用色",NSMakeRect(24,97,70,22),13);
  [view addSubview:patternLabel];
  self.patternScroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(101,94,227,28)];
  self.patternScroll.drawsBackground = NO;
  self.patternScroll.hasHorizontalScroller = YES;
  self.patternScroll.scrollerStyle = NSScrollerStyleOverlay;
  self.patternScroll.documentView = [[NSView alloc] initWithFrame:NSMakeRect(0,0,227,26)];
  [view addSubview:self.patternScroll];
  NSTextField* brushLabel = library_label(@"当前画笔",NSMakeRect(24,64,70,22),13);
  [view addSubview:brushLabel];
  self.brushSwatch = [self colorSwatch:0 action:@selector(openBrushPicker:)];
  [self.brushSwatch setFrameOrigin:NSMakePoint(102,63)];
  [self.brushSwatch setAccessibilityLabel:@"当前画笔，点击换色"];
  [view addSubview:self.brushSwatch];
  self.brush = [[KnitEditorColorWell alloc] initWithFrame:self.brushSwatch.frame];
  self.brush.hidden = YES;
  uint32_t initial = 0xfff1e3bd;
  for (NSUInteger i=0; i<self.cells.count; i++) if (pixels[i]) { initial = pixels[i]; break; }
  self.brush.color = library_color(initial);
  self.brush.confirmTitle = @"使用画笔色";
  self.brush.target = self; self.brush.action = @selector(chooseBrush:);
  [view addSubview:self.brush];
  if (!self.paletteDefaults) self.paletteDefaults = NSUserDefaults.standardUserDefaults;
  NSArray* savedColors = [self.paletteDefaults arrayForKey:grid_palette_key];
  self.palette = savedColors.mutableCopy ?: [@[@0xfff1e3bd,@0xffe5ad49,@0xffda6d78,
      @0xffa64a54,@0xff80a884,@0xff4a766c,@0xff75a6c5,@0xff8875a6,@0xff343948] mutableCopy];
  [self rebuildPalette];
  [self refreshPatternColors];
  NSView* firstSwatch = self.patternScroll.documentView.subviews.firstObject;
  NSRect patternSwatchFrame = [firstSwatch convertRect:firstSwatch.bounds toView:view];
  CGFloat patternLabelHeight = patternLabel.fittingSize.height;
  CGFloat brushLabelHeight = brushLabel.fittingSize.height;
  patternLabel.frame = NSMakeRect(24,NSMidY(patternSwatchFrame)-patternLabelHeight/2,70,patternLabelHeight);
  brushLabel.frame = NSMakeRect(24,NSMidY(self.brushSwatch.frame)-brushLabelHeight/2,70,brushLabelHeight);

  self.undoButton = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"arrow.uturn.backward" accessibilityDescription:@"撤销"] target:self action:@selector(undoEdit:)];
  self.redoButton = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"arrow.uturn.forward" accessibilityDescription:@"重做"] target:self action:@selector(redoEdit:)];
  self.undoButton.frame = NSMakeRect(24,24,38,30);
  self.redoButton.frame = NSMakeRect(66,24,38,30);
  self.undoButton.toolTip = @"撤销 (⌘Z)"; self.redoButton.toolTip = @"重做 (⇧⌘Z)";
  self.undoButton.keyEquivalent = @"z"; self.undoButton.keyEquivalentModifierMask = NSEventModifierFlagCommand;
  self.redoButton.keyEquivalent = @"Z"; self.redoButton.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagShift;
  [view addSubview:self.undoButton]; [view addSubview:self.redoButton];
  self.hint = library_label(@"图案最多使用 15 种线色。",NSMakeRect(114,27,328,22),12);
  [view addSubview:self.hint];
  [self refreshHistoryButtons];
  [self previewGrid];
}
- (void)cancelGrid:(id)sender {
  if (self.brush.active || self.background.active) [NSColorPanel.sharedColorPanel orderOut:nil];
  [self.brush deactivate]; [self.background deactivate];
  [self.history removeAllActions];
  [self.presentingViewController dismissViewController:self];
}
@end

@interface KnitPatternLibrary : NSWindowController <NSCollectionViewDataSource, NSCollectionViewDelegate, NSWindowDelegate, NSTextFieldDelegate> {
  struct knit_chart _draft;
  void (*_apply)(const char*);
  void (*_save)(void);
}
@property(strong) NSCollectionView* collection;
@property(strong) NSSegmentedControl* filter;
@property(strong) NSTextField* status;
@property(strong) NSTextField* nameField;

@property(strong) NSImageView* preview;
@property(strong) NSColorWell* base;
@property(strong) NSPopUpButton* spacing;
@property(strong) NSStepper* spacingStep;
@property(strong) NSPopUpButton* width;
@property(strong) NSButton* removeButton;
@property(strong) NSButton* gridButton;
@property(strong) NSButton* applyButton;
@property(strong) NSButton* exportButton;
@property(strong) NSButton* resetButton;
@property(strong) NSMutableArray<NSColorWell*>* yarns;
@property(strong) NSArray<NSNumber*>* originalColors;
@property(strong) NSData* originalPixels;
@property(strong) NSArray<NSString*>* names;
@property(strong) NSMutableDictionary<NSString*,NSImage*>* images;
@property(copy) NSString* selectedName;
@property BOOL dirty;
@property NSInteger currentFilter;
- (void)openWithApply:(void (*)(const char*))apply save:(void (*)(void))save;
@end

@implementation KnitPatternLibrary
- (instancetype)init {
  NSWindow* window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,960,760)
      styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
      backing:NSBackingStoreBuffered defer:NO];
  if (!(self = [super initWithWindow:window])) return nil;
  window.title = @"Window Festival · 图案库"; window.minSize = NSMakeSize(920,600);
  window.releasedWhenClosed = NO; window.delegate = self; [window center];
  NSView* content = window.contentView;
  NSViewController* host = [NSViewController new]; host.view = content; window.contentViewController = host;
  NSView* header = [[NSView alloc] initWithFrame:NSMakeRect(0,636,960,124)];
  header.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin; [content addSubview:header];
  NSTextField* title = library_label(@"针织图案库",NSMakeRect(24,77,440,30),24);
  title.font = [NSFont boldSystemFontOfSize:24]; [header addSubview:title];
  NSTextField* subtitle = library_label(@"挑选一款图案，织成自己的配色。",NSMakeRect(24,51,480,22),13);
  subtitle.textColor = NSColor.secondaryLabelColor; [header addSubview:subtitle];
  self.filter = [NSSegmentedControl segmentedControlWithLabels:@[@"全部",@"内置",@"我的图案"]
      trackingMode:NSSegmentSwitchTrackingSelectOne target:self action:@selector(filterChanged:)];
  self.filter.frame = NSMakeRect(24,10,268,26); self.filter.selectedSegment = 0; [header addSubview:self.filter];
  NSButton* guide = [NSButton buttonWithTitle:@"制作指南" target:self action:@selector(showGuide:)];
  guide.frame = NSMakeRect(448,77,98,30); guide.autoresizingMask = NSViewMinXMargin; [header addSubview:guide];
  NSButton* create = [NSButton buttonWithTitle:@"新建图案…" target:self action:@selector(newPattern:)];
  create.frame = NSMakeRect(552,77,126,30); create.autoresizingMask = NSViewMinXMargin; [header addSubview:create];
  self.removeButton = [NSButton buttonWithTitle:@"移到废纸篓…" target:self action:@selector(removePattern:)];
  self.removeButton.frame = NSMakeRect(816,10,126,26); self.removeButton.autoresizingMask = NSViewMinXMargin;
  [header addSubview:self.removeButton];
  NSButton* import = [NSButton buttonWithTitle:@"导入图案包…" target:self action:@selector(importPattern:)];
  import.frame = NSMakeRect(684,77,126,30); import.autoresizingMask = NSViewMinXMargin; [header addSubview:import];
  self.exportButton = [NSButton buttonWithTitle:@"导出图案包…" target:self action:@selector(exportPattern:)];
  self.exportButton.frame = NSMakeRect(816,77,126,30); self.exportButton.autoresizingMask = NSViewMinXMargin; [header addSubview:self.exportButton];
  NSScrollView* scroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(8,44,652,592)];
  scroll.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable; scroll.hasVerticalScroller = YES; scroll.drawsBackground = NO;
  self.collection = [[NSCollectionView alloc] initWithFrame:scroll.bounds];
  NSCollectionViewFlowLayout* layout = [NSCollectionViewFlowLayout new]; layout.itemSize = NSMakeSize(184,160);
  layout.minimumInteritemSpacing = 12; layout.minimumLineSpacing = 14; layout.sectionInset = NSEdgeInsetsMake(14,16,14,16);
  self.collection.collectionViewLayout = layout; self.collection.selectable = YES;
  self.collection.allowsMultipleSelection = NO; self.collection.dataSource = self; self.collection.delegate = self;
  self.collection.backgroundColors = @[NSColor.windowBackgroundColor];
  [self.collection registerClass:KnitPatternCard.class forItemWithIdentifier:@"pattern"];
  scroll.documentView = self.collection; [content addSubview:scroll];
  NSScrollView* details = [[NSScrollView alloc] initWithFrame:NSMakeRect(680,44,272,592)];
  details.autoresizingMask = NSViewMinXMargin | NSViewHeightSizable; details.hasVerticalScroller = YES;
  details.drawsBackground = NO;
  KnitLibraryPanel* panel = [[KnitLibraryPanel alloc] initWithFrame:NSMakeRect(0,0,252,592)];
  details.documentView = panel; [content addSubview:details];
  [panel addSubview:library_label(@"预览与配置",NSMakeRect(0,0,100,24),16)];
  self.gridButton = [NSButton buttonWithTitle:@"改针脚…" target:self action:@selector(editPattern:)];
  self.gridButton.frame = NSMakeRect(102,0,85,25); [panel addSubview:self.gridButton];
  self.resetButton = [NSButton buttonWithTitle:@"重置" target:self action:@selector(resetDraft:)];
  self.resetButton.frame = NSMakeRect(190,0,62,25); [panel addSubview:self.resetButton];
  self.preview = [[NSImageView alloc] initWithFrame:NSMakeRect(0,30,252,112)];
  self.preview.imageScaling = NSImageScaleProportionallyUpOrDown; [panel addSubview:self.preview];
  [panel addSubview:library_label(@"图案名称",NSMakeRect(0,152,252,18),12)];
  self.nameField = [[NSTextField alloc] initWithFrame:NSMakeRect(0,174,252,24)]; self.nameField.delegate = self;
  [self.nameField setAccessibilityLabel:@"图案名称"]; [panel addSubview:self.nameField];
  self.base = [[NSColorWell alloc] initWithFrame:NSMakeRect(0,212,38,27)];
  NSColorPanel.sharedColorPanel.showsAlpha = NO;
  self.base.target = self; self.base.action = @selector(configurationChanged:); [self.base setAccessibilityLabel:@"底色"];
  [panel addSubview:self.base]; [panel addSubview:library_label(@"底色",NSMakeRect(48,216,160,20),13)];
  [panel addSubview:library_label(@"线色",NSMakeRect(0,252,252,18),12)];
  self.yarns = [NSMutableArray array];
  for (int i=0;i<15;i++) {
    NSColorWell* well = [[NSColorWell alloc] initWithFrame:NSMakeRect((i%5)*50,278+(i/5)*30,40,24)];
    well.target = self; well.action = @selector(configurationChanged:);
    [well setAccessibilityLabel:[NSString stringWithFormat:@"线色 %d",i+1]];
    [self.yarns addObject:well]; [panel addSubview:well];
  }
  [panel addSubview:library_label(@"图案间距（按图案宽度）",NSMakeRect(0,378,252,20),12)];
  self.spacing = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0,402,196,24) pullsDown:NO];
  library_choice(self.spacing, @"贴合 · 0×", 0); library_choice(self.spacing, @"紧凑 · 0.25×", .25);
  library_choice(self.spacing, @"适中 · 0.75×", .75); library_choice(self.spacing, @"疏朗 · 1.5×", 1.5);
  library_choice(self.spacing, @"留白 · 3×", 3);
  self.spacing.target = self; self.spacing.action = @selector(configurationChanged:);
  [self.spacing setAccessibilityLabel:@"图案间距"]; [panel addSubview:self.spacing];
  self.spacingStep = [[NSStepper alloc] initWithFrame:NSMakeRect(210,400,36,26)];
  self.spacingStep.minValue = 0; self.spacingStep.maxValue = 3; self.spacingStep.increment = .05;
  self.spacingStep.valueWraps = NO; self.spacingStep.target = self; self.spacingStep.action = @selector(configurationChanged:);
  [self.spacingStep setAccessibilityLabel:@"微调间距，每次 0.05 倍"]; [panel addSubview:self.spacingStep];
  [panel addSubview:library_label(@"边框宽度",NSMakeRect(0,440,252,20),12)];
  self.width = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0,464,252,24) pullsDown:NO];
  for (NSUInteger i = 0; i < sizeof knit_width_presets / sizeof knit_width_presets[0]; i++)
    library_choice(self.width,[NSString stringWithFormat:@"%s · %g pt",knit_width_presets[i].name,knit_width_presets[i].value],knit_width_presets[i].value);
  self.width.target = self; self.width.action = @selector(configurationChanged:);
  [self.width setAccessibilityLabel:@"边框宽度"]; [panel addSubview:self.width];
  NSTextField* note = [NSTextField wrappingLabelWithString:@"修改后保存为新副本，原图案会保留。\n点击应用后才会更改桌面边框。"];
  note.frame = NSMakeRect(0,502,252,40); note.font = [NSFont systemFontOfSize:11]; note.textColor = NSColor.secondaryLabelColor; [panel addSubview:note];
  self.applyButton = [NSButton buttonWithTitle:@"应用此图案" target:self action:@selector(applyPattern:)];
  self.applyButton.frame = NSMakeRect(0,552,252,32); self.applyButton.bezelStyle = NSBezelStyleRounded;
  self.applyButton.keyEquivalent = @"\r"; [panel addSubview:self.applyButton];
  self.status = library_label(@"",NSMakeRect(24,12,900,22),12); self.status.textColor = NSColor.secondaryLabelColor;
  self.status.autoresizingMask = NSViewWidthSizable; [content addSubview:self.status];
  NSRect available = NSScreen.mainScreen.visibleFrame;
  [window setContentSize:NSMakeSize(fmin(960,available.size.width-40),fmin(760,available.size.height-60))];
  [window center];
  return self;
}
- (void)dealloc { free(_draft.px); }
- (void)showError:(NSError*)error {
  NSAlert* alert = [NSAlert new]; alert.messageText = @"无法完成操作";
  alert.informativeText = error.localizedDescription ?: @"请检查图案包或图案目录。";
  [alert beginSheetModalForWindow:self.window completionHandler:nil];
}
- (BOOL)canDiscard {
  if (!self.dirty) return YES;
  NSAlert* alert = [NSAlert new]; alert.messageText = @"放弃尚未保存的修改？";
  alert.informativeText = @"可以先保存并应用，或者导出图案包保留这次配色。";
  [alert addButtonWithTitle:@"继续编辑"]; [alert addButtonWithTitle:@"放弃修改"];
  return [alert runModal] == NSAlertSecondButtonReturn;
}
- (BOOL)windowShouldClose:(NSWindow*)sender { return [self canDiscard]; }
- (void)openWithApply:(void (*)(const char*))apply save:(void (*)(void))save {
  _apply = apply; _save = save;
  if (!self.window.visible) {
    self.dirty = NO; self.images = [NSMutableDictionary dictionary];
    [self refreshNames];
    NSString* initial = !g_knit_pattern_by_app && g_chart_active >= 0 ? @(g_charts[g_chart_active].name) : nil;
    [self selectName:initial && [self.names containsObject:initial] ? initial : self.names.firstObject];
  }
  [NSApp activateIgnoringOtherApps:YES]; [self showWindow:nil]; [self.window makeKeyAndOrderFront:nil];
}
- (void)refreshNames {
  NSMutableArray* names = [NSMutableArray array];
  for (int i=0;i<g_chart_count;i++) {
    struct knit_chart* c = &g_charts[i];
    if (!c->upright || c->generated || c->w != c->h || c->h < 4 || c->h > 14) continue;
    if (self.currentFilter == 1 && c->packaged) continue;
    if (self.currentFilter == 2 && !c->packaged) continue;
    [names addObject:@(c->name)];
  }
  self.names = names; [self.collection reloadData];
  self.status.stringValue = names.count ? [NSString stringWithFormat:@"%lu 个图案 · 图案包可离线导入、导出与分享", (unsigned long)names.count]
      : @"这里还没有图案。可以导入图案包，或从内置图案保存一个自己的配色。";
}
- (void)filterChanged:(id)sender {
  if (![self canDiscard]) { self.filter.selectedSegment = self.currentFilter; return; }
  self.dirty = NO; self.currentFilter = self.filter.selectedSegment; [self refreshNames]; [self selectName:self.names.firstObject];
}
- (NSInteger)collectionView:(NSCollectionView*)view numberOfItemsInSection:(NSInteger)section { return self.names.count; }
- (NSCollectionViewItem*)collectionView:(NSCollectionView*)view itemForRepresentedObjectAtIndexPath:(NSIndexPath*)path {
  KnitPatternCard* item = [view makeItemWithIdentifier:@"pattern" forIndexPath:path];
  [item view];
  NSString* name = self.names[path.item]; int index = knit_chart_index(name.UTF8String);
  if (index < 0) return item;
  struct knit_chart* c = &g_charts[index];
  if (!self.images[name]) self.images[name] = library_image(c,c->preferred_width ?: 28);
  item.imageView.image = self.images[name]; item.textField.stringValue = library_title(c);
  item.kind.stringValue = c->packaged ? @"我的图案" : @"内置 · 针织";
  [item.view setAccessibilityLabel:[NSString stringWithFormat:@"%@，%@",item.textField.stringValue,item.kind.stringValue]];
  return item;
}
- (void)collectionView:(NSCollectionView*)view didSelectItemsAtIndexPaths:(NSSet<NSIndexPath*>*)paths {
  if (!paths.count || paths.anyObject.item >= self.names.count) return;
  NSString* name = self.names[paths.anyObject.item];
  if ([name isEqualToString:self.selectedName]) return;
  if (![self canDiscard]) {
    NSUInteger old = self.selectedName ? [self.names indexOfObject:self.selectedName] : NSNotFound;
    if (old != NSNotFound) view.selectionIndexPaths = [NSSet setWithObject:[NSIndexPath indexPathForItem:old inSection:0]];
    else view.selectionIndexPaths = [NSSet set];
    return;
  }
  [self selectName:name];
}
- (void)selectName:(NSString*)name {
  free(_draft.px); memset(&_draft,0,sizeof _draft); self.dirty = NO; self.selectedName = name;
  int index = name ? knit_chart_index(name.UTF8String) : -1;
  self.removeButton.hidden = index < 0 || !g_charts[index].packaged;
  if (index >= 0) {
    _draft = g_charts[index];
    size_t size = (size_t)_draft.w*_draft.h*sizeof(uint32_t);
    _draft.px = malloc(size);
    if (_draft.px) memcpy(_draft.px,g_charts[index].px,size);
  }
  self.nameField.stringValue = index >= 0 ? library_title(&g_charts[index]) : @"";
  [self loadDraftControls];
  NSUInteger item = name ? [self.names indexOfObject:name] : NSNotFound;
  self.collection.selectionIndexPaths = item == NSNotFound ? [NSSet set]
      : [NSSet setWithObject:[NSIndexPath indexPathForItem:item inSection:0]];
}
- (void)loadDraftControls {
  BOOL enabled = _draft.px != NULL;
  self.applyButton.enabled = self.exportButton.enabled = self.gridButton.enabled = enabled;
  self.resetButton.enabled = enabled && self.selectedName != nil;
  self.nameField.enabled = self.base.enabled = self.spacing.enabled = self.spacingStep.enabled = self.width.enabled = enabled;
  for (NSColorWell* well in self.yarns) well.hidden = YES;
  if (!enabled) { self.preview.image = nil; return; }
  self.originalPixels = [NSData dataWithBytes:_draft.px length:(size_t)_draft.w*_draft.h*sizeof(uint32_t)];
  NSMutableArray* colors = [NSMutableArray array];
  for (int i=0;i<_draft.w*_draft.h;i++) if ((_draft.px[i]>>24)>=128 && ![colors containsObject:@(_draft.px[i] | 0xff000000u)]) [colors addObject:@(_draft.px[i] | 0xff000000u)];
  self.originalColors = colors;
  for (NSUInteger i=0;i<MIN(colors.count, self.yarns.count);i++) { self.yarns[i].hidden = NO; self.yarns[i].color = library_color([colors[i] unsignedIntValue]); }
  self.base.color = library_color(_draft.base_color);
  self.spacingStep.floatValue = _draft.spacing;
  [self selectSpacing:_draft.spacing];
  float width = _draft.preferred_width ?: 28;
  library_select_value(self.width,width,sizeof knit_width_presets / sizeof knit_width_presets[0],
      [NSString stringWithFormat:@"自定义 · %g pt",width]);
  [self updateDraft];
}
- (void)selectSpacing:(float)value {
  library_select_value(self.spacing,value,5,[NSString stringWithFormat:@"自定义 · %g×",value]);
}
- (void)resetDraft:(id)sender { [self selectName:self.selectedName]; }
- (void)configurationChanged:(id)sender {
  if (sender == self.spacing) self.spacingStep.floatValue = [self.spacing.selectedItem.representedObject floatValue];
  if (sender == self.spacingStep) [self selectSpacing:self.spacingStep.floatValue];
  self.dirty = YES; [self updateDraft];
}
- (void)controlTextDidChange:(NSNotification*)note { self.dirty = YES; [self updateDraft]; }
- (void)updateDraft {
  if (!_draft.px) return;
  snprintf(_draft.title,sizeof _draft.title,"%s",self.nameField.stringValue.UTF8String);
  _draft.base_color = library_hex(self.base.color); _draft.spacing = [self.spacing.selectedItem.representedObject floatValue];
  _draft.preferred_width = [self.width.selectedItem.representedObject floatValue];
  const uint32_t* original = self.originalPixels.bytes;
  for (int i=0;i<_draft.w*_draft.h;i++) {
    NSUInteger color = [self.originalColors indexOfObject:@(original[i] | 0xff000000u)];
    _draft.px[i] = (original[i]>>24)<128 ? 0 : color < self.yarns.count ? library_hex(self.yarns[color].color) : original[i];
  }
  self.preview.image = library_image(&_draft,_draft.preferred_width);
  self.applyButton.title = self.dirty ? @"保存副本并应用" : @"应用此图案";
}
- (NSData*)patternData {
  NSString* title = self.nameField.stringValue;
  if (title.length > 40 || [title lengthOfBytesUsingEncoding:NSUTF8StringEncoding] >= sizeof _draft.title) {
    [self showError:[NSError errorWithDomain:@"WindowFestival.Pattern" code:1 userInfo:@{NSLocalizedDescriptionKey:@"名称最多 40 个字符。"}]]; return nil;
  }
  [self updateDraft]; NSError* error = nil; NSData* data = knit_pattern_encode(&_draft,&error);
  if (!data) [self showError:error]; return data;
}
- (BOOL)installDocument:(NSData*)data apply:(BOOL)apply {
  if (g_chart_count >= KNIT_CHART_MAX) {
    [self showError:[NSError errorWithDomain:@"WindowFestival.Pattern" code:1 userInfo:@{NSLocalizedDescriptionKey:@"图案数量已达上限，请先重启应用释放自动取色缓存，或整理自定义图案目录。"}]]; return NO;
  }
  NSError* error = nil; NSString* name = knit_pattern_install(data,knit_charts_dir(),&error);
  if (!name) { [self showError:error]; return NO; }
  _apply("charts=reload");
  if (knit_chart_index(name.UTF8String) < 0) {
    [self showError:[NSError errorWithDomain:@"WindowFestival.Pattern" code:1 userInfo:@{NSLocalizedDescriptionKey:@"文件已保存，但未能加载。原来的图案选择保持不变。"}]]; return NO;
  }
  self.dirty = NO; self.currentFilter = self.filter.selectedSegment = 2; [self.images removeAllObjects];
  [self refreshNames]; [self selectName:name];
  if (apply) [self applyPattern:nil];
  return YES;
}
- (void)applyPattern:(id)sender {
  if (!_draft.px) return;
  if (self.dirty) { NSData* data = [self patternData]; if (data) [self installDocument:data apply:YES]; return; }
  int chart = knit_chart_index(self.selectedName.UTF8String);
  if (chart < 0) { [self refreshNames]; [self selectName:self.names.firstObject]; return; }
  _apply([[NSString stringWithFormat:@"width=%g",_draft.preferred_width] UTF8String]);
  _apply([[NSString stringWithFormat:@"chart=%@",self.selectedName] UTF8String]); _save();
  self.status.stringValue = [NSString stringWithFormat:@"已应用「%@」 · %g pt", self.nameField.stringValue,_draft.preferred_width];
}
- (void)showGuide:(id)sender {
  NSAlert* alert = [NSAlert new]; alert.messageText = @"从一格针脚开始";
  alert.informativeText = @"点「新建图案」从 12×12 的空白网格开始，也可以选一张内置卡片，再点「改针脚」。点右侧底色色块，选好后点「应用底色」。点左侧画笔色块，选好后点「使用画笔色」，或直接点图案用色、常用色。用图案用色里的底色色块可以补回空白针脚。要收藏新的线色，点「添加颜色」并在颜色面板确认。\n\n完成后可调整名称、配色、间距和宽度，再保存并应用，或导出 .knit.json 发给别人。收到同格式的包，用「导入图案包」加入我的图案。\n\n如果想用文本编辑器制作，可以先导出一份样例：grid 每行代表一行针脚，点号是底色，a、b、c…按顺序对应 palette 的线色。";
  [alert beginSheetModalForWindow:self.window completionHandler:nil];
}
- (void)newPattern:(id)sender {
  if (![self canDiscard]) return;
  [self openGrid:YES];
}
- (void)editPattern:(id)sender {
  if (!_draft.px) return;
  [self updateDraft]; [self openGrid:NO];
}
- (void)openGrid:(BOOL)blank {
  KnitGridEditor* editor = [KnitGridEditor new];
  editor->pattern = blank ? (struct knit_chart){.w=12,.h=12,.base_color=0xff365465,.spacing=.75f,
    .preferred_width=28,.upright=true,.solid_corners=true,.sculpted_yarn=true,.defined_yarn=true} : _draft;
  if (!blank) memcpy(editor->pixels,_draft.px,(size_t)_draft.w*_draft.h*sizeof(uint32_t));
  editor->pattern.px = editor->pixels;
  NSButton* cancel = [NSButton buttonWithTitle:@"取消" target:editor action:@selector(cancelGrid:)];
  cancel.keyEquivalent = @"\e"; cancel.frame = NSMakeRect(466,24,82,30); [editor.view addSubview:cancel];
  NSButton* done = [NSButton buttonWithTitle:@"完成针脚" target:self action:@selector(acceptGrid:)];
  done.frame = NSMakeRect(554,24,112,30); done.keyEquivalent = @"\r"; [editor.view addSubview:done];
  done.identifier = blank ? @"new" : @"edit";
  [self.window.contentViewController presentViewControllerAsSheet:editor];
}
- (void)acceptGrid:(NSButton*)sender {
  KnitGridEditor* editor = (KnitGridEditor*)self.window.contentViewController.presentedViewControllers.lastObject;
  if (![editor isKindOfClass:KnitGridEditor.class]) return;
  if ([self adoptGrid:editor blank:[sender.identifier isEqualToString:@"new"]])
    [editor cancelGrid:nil];
}
- (BOOL)adoptGrid:(KnitGridEditor*)editor blank:(BOOL)blank {
  struct knit_chart chart = editor->pattern;
  // Reuse the same grid and palette checks as export, independently of the name field.
  snprintf(chart.title,sizeof chart.title,"Draft");
  NSError* error = nil;
  if (!knit_pattern_encode(&chart,&error)) { editor.hint.stringValue = error.localizedDescription; return NO; }
  size_t size = (size_t)chart.w*chart.h*sizeof(uint32_t);
  uint32_t* copy = malloc(size);
  if (!copy) { editor.hint.stringValue = @"内存不足，无法保存草稿。"; return NO; }
  memcpy(copy,chart.px,size);
  if (blank) {
    [self selectName:nil]; self.nameField.stringValue = @"我的针织图案";
  }
  free(_draft.px); _draft = chart; _draft.px = copy;
  self.dirty = YES; [self loadDraftControls];
  return YES;
}
- (void)removePattern:(id)sender {
  int index = knit_chart_index(self.selectedName.UTF8String);
  if (index < 0 || !g_charts[index].packaged) return;
  NSAlert* alert = [NSAlert new];
  alert.messageText = [NSString stringWithFormat:@"将「%@」移到废纸篓？",library_title(&g_charts[index])];
  alert.informativeText = @"如果正在使用这款图案，边框会恢复「By App」。这款图案未保存的修改也会丢弃。";
  [alert addButtonWithTitle:@"取消"]; [alert addButtonWithTitle:@"移到废纸篓"];
  NSString* name = self.selectedName;
  [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse result) {
    if (result == NSAlertSecondButtonReturn) [self trashPattern:name];
  }];
}
- (NSURL*)trashPattern:(NSString*)name {
  int index = knit_chart_index(name.UTF8String);
  if (index < 0 || !g_charts[index].packaged) return nil;
  NSError* error = nil;
  NSURL* trashed = knit_pattern_trash(knit_charts_dir(),name,&error);
  if (!trashed) { [self showError:error]; return nil; }
  BOOL active = !g_knit_pattern_by_app && g_chart_active == index;
  if (active) _apply("chart=by-app");
  _apply("charts=reload");
  if (active) _save();
  self.dirty = NO; [self.images removeObjectForKey:name];
  [self refreshNames]; [self selectName:self.names.firstObject];
  self.status.stringValue = active ? @"已移到废纸篓，边框已恢复 By App。" : @"已移到废纸篓。";
  return trashed;
}
- (void)importPattern:(id)sender {
  if (![self canDiscard]) return;
  NSOpenPanel* panel = [NSOpenPanel openPanel]; panel.allowedContentTypes = @[UTTypeJSON];
  panel.canChooseDirectories = NO; panel.allowsMultipleSelection = NO; panel.prompt = @"导入";
  panel.message = @"选择 .knit.json 图案包。自己制作可从图案库的「新建图案」开始。";
  [panel beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse result) {
    if (result != NSModalResponseOK) return;
    NSError* error = nil; NSData* data = knit_pattern_read(panel.URL,&error);
    if (!data) { [self showError:error]; return; }
    if ([self installDocument:data apply:NO]) self.status.stringValue = @"已导入到「我的图案」，点击应用即可使用。";
  }];
}
- (void)exportPattern:(id)sender {
  NSData* data = [self patternData]; if (!data) return;
  NSSavePanel* panel = [NSSavePanel savePanel]; panel.allowedContentTypes = @[UTTypeJSON];
  // Suggested filename is deliberately independent of the editable display name.
  panel.nameFieldStringValue = @"my-pattern.knit.json"; panel.prompt = @"导出";
  [panel beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse result) {
    if (result != NSModalResponseOK) return;
    NSError* error = nil;
    if (![data writeToURL:panel.URL options:NSDataWritingAtomic error:&error]) [self showError:error];
    else self.status.stringValue = @"图案包已导出，可在另一台电脑导入。";
  }];
}
@end

void knit_library_show(void (*apply)(const char*), void (*save_preferences)(void)) {
  static KnitPatternLibrary* library;
  if (!library) library = [KnitPatternLibrary new];
  [library openWithApply:apply save:save_preferences];
}
