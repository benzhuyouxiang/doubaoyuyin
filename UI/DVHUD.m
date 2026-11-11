#import "DVHUD.h"

static UIView *_box = nil;
static UILabel *_label = nil;
static NSTimer *_timer = nil;

@implementation DVHUD

+ (UIWindow *)dv_window {
    UIWindow *key = nil;
    for (UIWindow *w in [UIApplication sharedApplication].windows) {
        if (w.isKeyWindow) { key = w; break; }
    }
    if (!key) key = [UIApplication sharedApplication].windows.firstObject;
    return key;
}

+ (void)show:(NSString *)text {
    NSString *t = text ?: @"";
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *w = [self dv_window];
        if (!w) return;

        if (!_box) {
            _box = [[UIView alloc] initWithFrame:CGRectZero];
            _box.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.82];
            _box.layer.cornerRadius = 12;
            _box.userInteractionEnabled = NO;

            _label = [[UILabel alloc] initWithFrame:CGRectZero];
            _label.textColor = [UIColor whiteColor];
            _label.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
            _label.numberOfLines = 0;
            _label.textAlignment = NSTextAlignmentCenter;
            [_box addSubview:_label];
        }
        if (!_box.superview) [w addSubview:_box];

        _label.text = t;
        CGSize sz = [t boundingRectWithSize:CGSizeMake(260, CGFLOAT_MAX)
                                    options:NSStringDrawingUsesLineFragmentOrigin
                                 attributes:@{NSFontAttributeName: _label.font}
                                    context:nil].size;
        CGFloat bw = MAX(120, sz.width + 32);
        CGFloat bh = MAX(40, sz.height + 24);
        _box.frame = CGRectMake((w.bounds.size.width - bw) / 2,
                                w.bounds.size.height - bh - 220, bw, bh);
        _label.frame = CGRectMake(16, 12, bw - 32, bh - 24);
        _box.alpha = 1;

        [_timer invalidate];
        _timer = [NSTimer scheduledTimerWithTimeInterval:2.5
                                                 repeats:NO
                                                   block:^(NSTimer *tm) {
            [UIView animateWithDuration:0.25 animations:^{ _box.alpha = 0; }];
        }];
    });
}

+ (void)showError:(NSString *)text {
    [self show:[@"⚠️ " stringByAppendingString:(text ?: @"")]];
}

+ (void)hide {
    dispatch_async(dispatch_get_main_queue(), ^{
        [_timer invalidate];
        _timer = nil;
        [_box removeFromSuperview];
        _box = nil;
        _label = nil;
    });
}

@end
