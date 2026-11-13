// Optional native integration check. Uses only its own window and temporary pattern directory.
#import <Cocoa/Cocoa.h>
#include "misc/chart.h"
#include "misc/apps.h"
#include "parse.h"
#define knit_charts_dir library_test_directory
const char* library_test_directory(void);
#include "../src/library.m"
#undef knit_charts_dir
#include <assert.h>

static char pattern_directory[] = "/tmp/window-festival-library.XXXXXX";
static int saves;
static struct settings settings = {.border_width=28};
const char* library_test_directory(void) { return pattern_directory; }
static void apply(const char* arg) {
  if (!strcmp(arg,"charts=reload")) { knit_charts_load(pattern_directory); knit_flush_cache(); }
  else { char* argument=(char*)arg; assert(parse_settings(&settings,1,&argument)); }
}
static void save(void) { saves++; }

int main(void) {
  @autoreleasepool {
    assert(mkdtemp(pattern_directory));
    [NSApplication.sharedApplication setActivationPolicy:NSApplicationActivationPolicyAccessory];
    knit_charts_load(NULL);
    KnitPatternLibrary* library = [KnitPatternLibrary new];
    [library openWithApply:apply save:save];
    assert(library.names.count==56 && library.preview.image);
    library.filter.selectedSegment=1;
    [library filterChanged:nil];
    assert(library.names.count==56 && [library.names containsObject:@"zigzag"]);
    [library selectName:@"atelier-messages"]; // Non-square upstream chart with its original renderer.
    assert(library.preview.image && library.applyButton.enabled && !library.gridButton.enabled);
    [library selectName:@"zigzag"];
    [library selectName:@"festival-daisy"];
    uint32_t original=g_charts[knit_chart_index("festival-daisy")].base_color;
    library.nameField.stringValue=@"暮色雏菊";
    library.base.color=library_color(0xff67507a); [library.spacing selectItemWithTitle:@"疏朗 · 1.5×"];
    [library configurationChanged:library.spacing];
    [library.width selectItemWithTitle:@"Wide · 18 pt"];
    [library configurationChanged:nil];
    assert(library.dirty && g_charts[knit_chart_index("festival-daisy")].base_color==original);
    NSData* data=[library patternData]; assert(data);
    struct knit_chart decoded={0}; assert(knit_pattern_decode(data,&decoded,nil));
    assert(decoded.base_color==0xff67507a && decoded.spacing==1.5 && decoded.preferred_width==18); free(decoded.px);
    // Exercise the production save/apply path with real disk IO, real parser, and isolated callbacks.
    [library applyPattern:nil];
    assert(saves==1 && !library.dirty && !g_knit_pattern_by_app && settings.border_width==18);
    assert(g_charts[g_chart_active].packaged && !strcmp(g_charts[g_chart_active].title,"暮色雏菊"));
    NSString* imported=library.selectedName;
    assert([library installDocument:data apply:NO]);
    assert(![library.selectedName isEqual:imported] && saves==1 && library.names.count==2);
    assert([[NSData dataWithContentsOfFile:[@(pattern_directory) stringByAppendingPathComponent:[imported stringByAppendingString:@".knit.json"]]] isEqual:data]);
    [library.window close]; [library openWithApply:apply save:save];
    assert([library.selectedName isEqual:imported]);
    // Arbitrary valid package settings survive selection without slider rounding.
    struct knit_chart fractional = g_charts[g_chart_active];
    fractional.spacing = 1.1f; fractional.preferred_width = 14.5f;
    NSData* fractionalData = knit_pattern_encode(&fractional,nil); assert(fractionalData);
    assert([library installDocument:fractionalData apply:YES]);
    assert([library.spacing.selectedItem.representedObject floatValue]==1.1f && [library.width.selectedItem.representedObject floatValue]==14.5f);
    assert(settings.border_width==14.5f);
    library.spacingStep.doubleValue += library.spacingStep.increment;
    [library configurationChanged:library.spacingStep];
    assert(fabsf([library.spacing.selectedItem.representedObject floatValue]-1.15f)<1e-6);
    NSString* active = library.selectedName;
    assert(![library trashPattern:@"festival-daisy"]);
    NSURL* trashed = [library trashPattern:active]; assert(trashed);
    assert([NSFileManager.defaultManager removeItemAtURL:trashed error:nil]);
    assert(knit_chart_index(active.UTF8String)<0 && g_knit_pattern_by_app && saves==3 && library.names.count==2);
    // Edit a copy and build a fresh motif with the same controls used by the sheet.
    [library selectName:@"festival-daisy"];
    uint32_t originalStitch=g_charts[knit_chart_index("festival-daisy")].px[0];
    KnitGridEditor* editor = [KnitGridEditor new];
    assert(knit_pattern_decode(data,&editor->pattern,nil));
    memcpy(editor->pixels,editor->pattern.px,editor->pattern.w*editor->pattern.h*sizeof(uint32_t));
    free(editor->pattern.px); editor->pattern.px=editor->pixels;
    NSString* paletteSuite = [@"WindowFestival.EditorTest." stringByAppendingString:NSUUID.UUID.UUIDString];
    editor.paletteDefaults = [[NSUserDefaults alloc] initWithSuiteName:paletteSuite];
    [editor view];
    NSButton* cell = editor.cells.firstObject;
    uint32_t startingStitch = editor->pixels[0];
    uint32_t startingGround = editor->pattern.base_color;
    editor.brush.color = library_color(0xffcc8844);
    [editor chooseBrush:editor.brush];
    assert([[editor.brushSwatch accessibilityValue] isEqual:@"#CC8844"]);
    [cell performClick:nil]; assert(editor->pixels[0]==0xffcc8844 && editor.undoButton.enabled);
    editor.background.color = library_color(0xff263f4e);
    [editor changeGround:editor.background];
    assert(editor->pattern.base_color==0xff263f4e);
    [editor.undoButton performClick:nil];
    assert(editor->pattern.base_color==startingGround && editor->pixels[0]==0xffcc8844);
    [editor.undoButton performClick:nil];
    assert(editor->pixels[0]==startingStitch && !editor.undoButton.enabled && editor.redoButton.enabled);
    [editor.redoButton performClick:nil];
    [editor.redoButton performClick:nil];
    assert(editor->pattern.base_color==0xff263f4e && editor->pixels[0]==0xffcc8844);
    assert([editor.patternColors containsObject:@0xffcc8844]);
    NSButton* ground = editor.patternScroll.documentView.subviews.firstObject;
    [ground performClick:nil];
    [cell performClick:nil];
    assert(editor->pixels[0]==0 && editor.usesGround);
    assert(![editor.patternColors containsObject:@0xffcc8844]);
    [editor undoEdit:nil];
    assert(editor->pixels[0]==0xffcc8844 && [editor.patternColors containsObject:@0xffcc8844]);
    for (NSButton* swatch in editor.patternScroll.documentView.subviews) {
      if (swatch.tag==0xffcc8844) { [swatch performClick:nil]; break; }
    }
    assert(!editor.usesGround && library_hex(editor.brush.committedColor)==0xffcc8844);
    assert(![editor.palette containsObject:@0xffcc8844]);
    NSImage* previousPreview = editor.preview.image;
    [editor.previewWidth selectItemWithTitle:@"Slim · 6 pt"];
    [editor changePreviewWidth:nil];
    assert(editor.preview.image != previousPreview && editor->pattern.preferred_width==18);
    NSUInteger swatchCount = editor.palette.count;
    [editor chooseBrush:nil];
    [editor addBrushColor:nil];
    assert(editor.palette.count==swatchCount+1 && [editor brushIndex]==swatchCount);
    // Reordering and deletion update the saved swatches, without changing already painted stitches.
    [editor.manage performClick:nil];
    [editor moveSwatch:editor.moveLeft];
    assert([editor brushIndex]==swatchCount-1);
    assert([[editor.paletteDefaults arrayForKey:grid_palette_key] isEqualToArray:editor.palette]);
    [editor.removeColor performClick:nil];
    assert(editor.palette.count==swatchCount && editor->pixels[0]==0xffcc8844);
    [editor.paletteDefaults removePersistentDomainForName:paletteSuite];
    NSData* named = [library editedDocument:editor title:@"桂花" error:nil];
    assert(named && ![library editedDocument:editor title:@"  " error:nil]);
    assert(g_charts[knit_chart_index("festival-daisy")].px[0]==originalStitch);
    memset(editor->pixels,0,sizeof editor->pixels);
    assert(![library editedDocument:editor title:@"桂花" error:nil]);
    [cell performClick:nil];
    assert([library installDocument:[library editedDocument:editor title:@"桂花" error:nil] apply:YES]);
    assert(saves==4 && g_charts[g_chart_active].packaged && !strcmp(g_charts[g_chart_active].title,"桂花"));
    NSString* savedName = library.selectedName;
    NSUInteger savedCount = library.names.count;
    NSData* renamed = [library editedDocument:editor title:@"桂花新版" error:nil];
    assert(![library writeDocument:renamed replacing:@"festival-daisy" error:nil]);
    assert(![library writeDocument:[NSData data] replacing:savedName error:nil]);
    assert([[library writeDocument:renamed replacing:savedName error:nil] isEqual:savedName]);
    assert([library showSavedPattern:savedName apply:NO]);
    assert(library.names.count==savedCount && [library.nameField.stringValue isEqual:@"桂花新版"]);
    assert(!strcmp(g_charts[g_chart_active].name,savedName.UTF8String));
    assert([library installDocument:named apply:NO]);
    assert(library.names.count==savedCount+1 && ![library.selectedName isEqual:savedName]);
    // Check the minimum window: both the gallery and inspector remain scrollable.
    [library.window setContentSize:NSMakeSize(920,580)]; [library.window.contentView layoutSubtreeIfNeeded];
    int scrollViews=0; for(NSView* view in library.window.contentView.subviews) if([view isKindOfClass:NSScrollView.class]) {
      assert(view.frame.size.height>0 && [(NSScrollView*)view hasVerticalScroller]); scrollViews++;
    }
    assert(scrollViews==2);
    // Capture a normal gallery view without test documents or unsaved edits.
    knit_charts_load(NULL); knit_flush_cache();
    library.currentFilter=library.filter.selectedSegment=0; [library.images removeAllObjects];
    [library refreshNames]; [library selectName:@"festival-daisy"];
    [library.window setContentSize:NSMakeSize(960,760)]; [library.window center];
    BOOL showEditor = [NSProcessInfo.processInfo.arguments containsObject:@"--editor"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,400*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
      [library.window.contentView layoutSubtreeIfNeeded]; [library.window displayIfNeeded];
      assert(library.collection.visibleItems.count>0);
      for(NSCollectionViewItem* item in library.collection.visibleItems) assert(item.imageView.image && item.textField.stringValue.length);
      if (showEditor) [library editPattern:nil];
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW,750*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
        assert(!showEditor || library.window.attachedSheet.visible);
        fprintf(stderr,"LIBRARY_WINDOW %ld\n",(long)(showEditor ? library.window.attachedSheet.windowNumber : library.window.windowNumber));
      });
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW,4*NSEC_PER_SEC),dispatch_get_main_queue(),^{
        if (showEditor) {
          KnitGridEditor* sheet = (KnitGridEditor*)library.window.contentViewController.presentedViewControllers.lastObject;
          assert([sheet isKindOfClass:KnitGridEditor.class]);
          NSColorPanel* panel = NSColorPanel.sharedColorPanel;
          [sheet.background performClick:nil];
          assert(panel.visible && sheet.background.active);
          assert(NSMinX(panel.frame) >= NSMidX(sheet.view.window.frame));
          NSImage* priorPreview = sheet.preview.image;
          panel.color = library_color(0xffac5237);
          assert(sheet->pattern.base_color!=0xffac5237);
          [sheet.background.confirmButton performClick:nil];
          assert(sheet->pattern.base_color==0xffac5237 && sheet.preview.image!=priorPreview);
          NSColor* cellGround = [NSColor colorWithCGColor:sheet.cells.firstObject.layer.backgroundColor];
          assert(library_hex(cellGround)==0xffac5237);
          [sheet.brushSwatch performClick:nil];
          assert(sheet.brush.active && !sheet.background.active && panel.accessoryView);
          panel.color = library_color(0xff206757);
          assert(![sheet.palette containsObject:@0xff206757]);
          [sheet.brush.confirmButton performClick:nil];
          assert(![sheet.palette containsObject:@0xff206757]);
          assert([[sheet.brushSwatch accessibilityValue] isEqual:@"#206757"]);
          assert(sheet->pattern.base_color==0xffac5237);
          sheet.paletteDefaults = [[NSUserDefaults alloc] initWithSuiteName:paletteSuite];
          [sheet openPalettePicker:nil];
          assert(sheet.brush.active && panel.accessoryView);
          panel.color = library_color(0xff123abc);
          NSButton* addColor = (NSButton*)panel.accessoryView.subviews.firstObject;
          [addColor performClick:nil];
          assert(!panel.visible && !panel.accessoryView && [sheet.palette containsObject:@0xff123abc]);
          [sheet.paletteDefaults removePersistentDomainForName:paletteSuite];
          NSButton* done = sheet.view.subviews.lastObject;
          NSTimer* naming = [NSTimer timerWithTimeInterval:.3 repeats:NO block:^(NSTimer* timer) {
            NSWindow* modal = NSApp.modalWindow;
            assert(modal && modal!=sheet.view.window);
            NSText* fieldEditor = (NSText*)modal.firstResponder;
            assert([fieldEditor.string isEqual:@"雏菊 副本"]);
            [fieldEditor setString:@"窗口测试图案"];
            [modal makeFirstResponder:nil];
            [NSApp stopModalWithCode:NSAlertFirstButtonReturn];
          }];
          [NSRunLoop.mainRunLoop addTimer:naming forMode:NSModalPanelRunLoopMode];
          [done performClick:nil];
          assert(!library.dirty && [library.nameField.stringValue isEqualToString:@"窗口测试图案"]);
          assert(library.currentFilter==2 && g_charts[knit_chart_index(library.selectedName.UTF8String)].packaged);
        }
        assert([NSFileManager.defaultManager removeItemAtPath:@(pattern_directory) error:nil]);
        [library.window orderOut:nil];
        puts("PASS: native cards; live edits; save-copy/apply; duplicate import; reopen; scrollable layout; presets and spacing step; trash/fallback; grid edits, undo/redo, real color panel confirmation, reusing pattern colors, palette management, preview width; built-ins unchanged");
        exit(0);
      });
    });
    [NSApp run];
  }
}
