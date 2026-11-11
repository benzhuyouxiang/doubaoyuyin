#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#import "TTS/DVProtocol.h"
#import "TTS/DVTTSEngine.h"
#import "UI/DVHUD.h"
#import "UI/DVMenuController.h"
#import "Prefs/DVStore.h"
#import "Prefs/DVSettingsController.h"

static const void *kDVTapHookedKey = &kDVTapHookedKey;

#pragma mark - 取文字

static NSString *dv_text_of(UIView *view) {
    if (!view) return nil;

    @try {
        if ([view isKindOfClass:[UITextView class]]) {
            UITextView *tv = (UITextView *)view;
            NSString *sel = [tv textInRange:tv.selectedTextRange];
            if (sel.length) return sel;
            return tv.text;
        }
        if ([view isKindOfClass:[UITextField class]]) {
            UITextField *tf = (UITextField *)view;
            NSString *t = tf.text;
            if (t.length) return t;
            return nil;
        }
        if ([view isKindOfClass:[UILabel class]]) {
            UILabel *lb = (UILabel *)view;
            NSAttributedString *at = lb.attributedText;
            if (at.length) return at.string;
            return lb.text;
        }
    } @catch (NSException *e) {
        NSLog(@"[豆包语音] dv_text_of 异常: %@", e.reason);
    }
    return nil;
}

#pragma mark - 判断

static BOOL dv_is_readable_text_view(UIView *view) {
    if (!view) return NO;
    if (view.window == nil) return NO;

    @try {
        CGRect f = view.frame;
        if (f.size.height < 10 || f.size.width < 24) return NO;

        NSString *cn = NSStringFromClass([view class]);
        if ([cn containsString:@"Button"]) return NO;
        if ([cn containsString:@"NavigationBar"]) return NO;
        if ([cn containsString:@"TabBar"]) return NO;
        if ([cn containsString:@"Keyboard"]) return NO;
        if ([cn containsString:@"SearchBar"]) return NO;

        NSString *txt = dv_text_of(view);
        if (txt.length < 1) return NO;
        return YES;
    } @catch (NSException *e) {
        return NO;
    }
}

#pragma mark - 挂长按

static void dv_handle_reader_long_press(UIView *view, UIGestureRecognizer *g) {
    if (g.state != UIGestureRecognizerStateBegan) return;

    NSString *txt = dv_text_of(view);
    txt = [txt stringByTrimmingCharactersInSet:
              [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (txt.length == 0) return;
    if (txt.length > 4000) txt = [txt substringToIndex:4000];

    UIViewController *host = view.window.rootViewController;
    while (host.presentedViewController) host = host.presentedViewController;
    if (!host) return;

    [DVMenuController presentForText:txt host:host];
}

static void dv_attach_reader(UIView *view) {
    if (!DVEnableLongPress()) return;
    if (!dv_is_readable_text_view(view)) return;
    if (objc_getAssociatedObject(view, kDVTapHookedKey)) return;
    objc_setAssociatedObject(view, kDVTapHookedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    UILongPressGestureRecognizer *g =
        [[UILongPressGestureRecognizer alloc] initWithTarget:view
                                                      action:@selector(dv_readerLongPress:)];
    g.minimumPressDuration = 0.5;
    g.numberOfTouchesRequired = 1;
    g.cancelsTouchesInView = NO;
    g.delaysTouchesBegan = NO;
    [view addGestureRecognizer:g];

    NSLog(@"[豆包语音] 挂上 → %@", NSStringFromClass([view class]));
}

#pragma mark - 手势

@interface UIView (DVReader)
- (void)dv_readerLongPress:(UILongPressGestureRecognizer *)g;
@end

@implementation UIView (DVReader)
- (void)dv_readerLongPress:(UILongPressGestureRecognizer *)g {
    @try {
        dv_handle_reader_long_press(self, g);
    } @catch (NSException *e) {
        NSLog(@"[豆包语音] 长按异常: %@", e.reason);
    }
}
@end

#pragma mark - hook UILabel（只留 didMoveToWindow，删掉 layoutSubviews）

%hook UILabel

- (void)didMoveToWindow {
    %orig;
    @try {
        if (!self.window) return;
        dv_attach_reader(self);
    } @catch (NSException *e) {
        NSLog(@"[豆包语音] UILabel hook 异常: %@", e.reason);
    }
}

%end

#pragma mark - hook UITextView

%hook UITextView

- (void)didMoveToWindow {
    %orig;
    @try {
        if (!self.window) return;
        dv_attach_reader(self);
    } @catch (NSException *e) {
        NSLog(@"[豆包语音] UITextView hook 异常: %@", e.reason);
    }
}

%end

#pragma mark - 启动（不 hook 任何 UIViewController）

%ctor {
    @autoreleasepool {
        NSLog(@"[豆包语音] dylib 已注入 %@ (pid=%d) longPress=%d",
              [[NSBundle mainBundle] bundleIdentifier], getpid(),
              (int)DVEnableLongPress());
        [DVStore shared];
    }
}
