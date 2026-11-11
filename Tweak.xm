#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#import "TTS/DVProtocol.h"
#import "TTS/DVTTSEngine.h"
#import "UI/DVHUD.h"
#import "UI/DVMenuController.h"
#import "UI/DVMoreInjector.h"
#import "Prefs/DVStore.h"
#import "Prefs/DVSettingsController.h"

#pragma mark - 微信私有类声明（编译期没有头文件）

@interface WCMoreFunctionViewController : UIViewController
@end

@interface WCMoreViewController : UIViewController
@end

@interface MMGrowTextView : UIView
@end

@interface NewMainFrameViewController : UIViewController
@end

static const void *kDVTapHookedKey = &kDVTapHookedKey;

#pragma mark - 取视图里的文字

static NSString *dv_text_of(UIView *view) {
    if (!view) return nil;

    if ([view isKindOfClass:[UITextView class]]) {
        UITextView *tv = (UITextView *)view;
        NSString *sel = [tv textInRange:tv.selectedTextRange];
        if (sel.length) return sel;
        return tv.text;
    }

    if ([view isKindOfClass:[UITextField class]]) {
        UITextField *tf = (UITextField *)view;
        UITextRange *r = tf.selectedTextRange;
        if (r) {
            NSString *sel = [tf textInRange:r];
            if (sel.length) return sel;
        }
        return tf.text;
    }

    if ([view isKindOfClass:[UILabel class]]) {
        UILabel *lb = (UILabel *)view;
        if (lb.attributedText.length) return lb.attributedText.string;
        return lb.text;
    }

    if ([view respondsToSelector:@selector(text)]) {
        id t = [view performSelector:@selector(text)];
        if ([t isKindOfClass:[NSString class]] && [(NSString *)t length]) return t;
    }
    if ([view respondsToSelector:@selector(attributedText)]) {
        id t = [view performSelector:@selector(attributedText)];
        if ([t isKindOfClass:[NSAttributedString class]]) {
            NSString *s = [(NSAttributedString *)t string];
            if (s.length) return s;
        }
    }
    return nil;
}

#pragma mark - 该不该挂长按

static BOOL dv_is_readable_text_view(UIView *view) {
    if (!view) return NO;
    if (view.window == nil) return NO;

    CGRect f = view.frame;
    if (f.size.height < 10 || f.size.width < 24) return NO;

    NSString *cn = NSStringFromClass([view class]);
    if ([cn containsString:@"Button"]) return NO;
    if ([cn containsString:@"NavigationBar"]) return NO;
    if ([cn containsString:@"TabBar"]) return NO;
    if ([cn containsString:@"Keyboard"]) return NO;
    if ([cn containsString:@"SearchBar"]) return NO;
    if ([cn hasPrefix:@"_UI"]) return NO;

    NSString *txt = dv_text_of(view);
    if (txt.length < 1) return NO;
    return YES;
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
    if (!DVEnableLongPress()) return;           // 设置页的总开关
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

    NSLog(@"[豆包语音] 已挂长按 → %@", NSStringFromClass([view class]));
}

#pragma mark - 手势回调

@interface UIView (DVReader)
- (void)dv_readerLongPress:(UILongPressGestureRecognizer *)g;
@end

@implementation UIView (DVReader)

- (void)dv_readerLongPress:(UILongPressGestureRecognizer *)g {
    dv_handle_reader_long_press(self, g);
}

@end

#pragma mark - hook: UILabel

%hook UILabel

- (void)didMoveToWindow {
    %orig;
    if (!self.window) return;
    dv_attach_reader(self);
}

- (void)layoutSubviews {
    %orig;
    if (!self.window) return;
    dv_attach_reader(self);
}

%end

#pragma mark - hook: UITextView / UITextField

%hook UITextView

- (void)didMoveToWindow {
    %orig;
    if (!self.window) return;
    dv_attach_reader(self);
}

%end

%hook UITextField

- (void)didMoveToWindow {
    %orig;
    if (!self.window) return;
    dv_attach_reader(self);
}

%end

#pragma mark - hook: 微信输入框 MMGrowTextView

%hook MMGrowTextView

- (void)didMoveToWindow {
    %orig;
    if (!self.window) return;
    NSLog(@"[豆包语音] 命中微信输入框 MMGrowTextView");
    dv_attach_reader(self);
}

- (void)layoutSubviews {
    %orig;
    if (!self.window) return;
    dv_attach_reader(self);
}

%end

#pragma mark - 加号面板（设置入口）

static void dv_try_install_more(id vcObj) {
    if (!vcObj) return;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        UIViewController *vc = (UIViewController *)vcObj;
        if ([vc isKindOfClass:[UIViewController class]]) {
            [DVMoreInjector installInto:vc];
        }
    });
}

%hook WCMoreFunctionViewController

- (void)viewDidLoad {
    %orig;
    dv_try_install_more(self);
}

%end

%hook WCMoreViewController

- (void)viewDidLoad {
    %orig;
    dv_try_install_more(self);
}

%end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    NSString *cn = NSStringFromClass([self class]);
    if ([cn containsString:@"DVMore"]) return;
    if ([cn containsString:@"More"] || [cn containsString:@"Function"] ||
        [cn containsString:@"Panel"] || [cn containsString:@"Menu"]) {
        dv_try_install_more(self);
    }
}

%end

#pragma mark - 「我」页右上角设置入口（保底入口）

%hook NewMainFrameViewController

- (void)viewDidLoad {
    %orig;
    if (objc_getAssociatedObject(self, "dv_mine_btn")) return;
    objc_setAssociatedObject(self, "dv_mine_btn", @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    UIBarButtonItem *item =
        [[UIBarButtonItem alloc] initWithTitle:@"豆包"
                                        style:UIBarButtonItemStylePlain
                                       target:self
                                       action:@selector(dv_openSettings)];
    NSMutableArray *items = [self.navigationItem.rightBarButtonItems mutableCopy]
        ?: [NSMutableArray array];
    [items addObject:item];
    self.navigationItem.rightBarButtonItems = items;
}

- (void)dv_openSettings {
    [DVMenuController openSettingsFrom:self];
}

%end

#pragma mark - 启动

%ctor {
    @autoreleasepool {
        NSLog(@"[豆包语音] dylib 已注入 %@ (pid=%d) longPress=%d streamPlay=%d",
              [[NSBundle mainBundle] bundleIdentifier], getpid(),
              (int)DVEnableLongPress(), (int)DVStreamPlay());
        [DVStore shared];
    }
}
