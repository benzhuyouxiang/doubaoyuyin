#import "DVMoreInjector.h"
#import "DVMenuController.h"
#import "DVHUD.h"
#import <objc/runtime.h>

static const void *kDVMoreDSKey = &kDVMoreDSKey;
static const void *kDVMoreDGKey = &kDVMoreDGKey;

#pragma mark - 自绘 cell

@interface DVMoreCell : UICollectionViewCell
@end

@implementation DVMoreCell

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        CGFloat w = frame.size.width > 0 ? frame.size.width : 60;
        CGFloat side = MIN(w, frame.size.height > 0 ? frame.size.height : 80);
        CGFloat boxSide = side * 0.52;

        UIView *box = [[UIView alloc] initWithFrame:CGRectMake((w - boxSide) / 2, 6, boxSide, boxSide)];
        box.backgroundColor = [UIColor colorWithRed:0.98 green:0.42 blue:0.35 alpha:1.0];
        box.layer.cornerRadius = boxSide * 0.28;
        box.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        [self.contentView addSubview:box];

        UILabel *glyph = [[UILabel alloc] initWithFrame:box.bounds];
        glyph.text = @"声";
        glyph.textColor = [UIColor whiteColor];
        glyph.font = [UIFont systemFontOfSize:boxSide * 0.48 weight:UIFontWeightSemibold];
        glyph.textAlignment = NSTextAlignmentCenter;
        [box addSubview:glyph];

        UILabel *name = [[UILabel alloc] initWithFrame:CGRectMake(0, CGRectGetMaxY(box.frame) + 6, w, 16)];
        name.text = @"豆包语音";
        name.font = [UIFont systemFontOfSize:11];
        name.textColor = [UIColor secondaryLabelColor];
        name.textAlignment = NSTextAlignmentCenter;
        [self.contentView addSubview:name];
    }
    return self;
}

@end

#pragma mark - dataSource 包装

@interface DVMoreDataSourceProxy : NSObject <UICollectionViewDataSource>
@property (nonatomic, weak) id<UICollectionViewDataSource> inner;
@end

@implementation DVMoreDataSourceProxy

- (BOOL)respondsToSelector:(SEL)aSelector {
    if (aSelector == @selector(collectionView:numberOfItemsInSection:) ||
        aSelector == @selector(collectionView:cellForItemAtIndexPath:) ||
        aSelector == @selector(numberOfSectionsInCollectionView:)) {
        return YES;
    }
    if (self.inner && [self.inner respondsToSelector:aSelector]) return YES;
    return [super respondsToSelector:aSelector];
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)cv {
    if (self.inner && [self.inner respondsToSelector:@selector(numberOfSectionsInCollectionView:)]) {
        return [self.inner numberOfSectionsInCollectionView:cv];
    }
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)cv numberOfItemsInSection:(NSInteger)section {
    NSInteger n = 0;
    id<UICollectionViewDataSource> in = self.inner;
    if (in && [in respondsToSelector:@selector(collectionView:numberOfItemsInSection:)]) {
        n = [in collectionView:cv numberOfItemsInSection:section];
    }
    return n + 1;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)cv
                  cellForItemAtIndexPath:(NSIndexPath *)ip {
    id<UICollectionViewDataSource> in = self.inner;
    NSInteger innerCount = 0;
    if (in && [in respondsToSelector:@selector(collectionView:numberOfItemsInSection:)]) {
        innerCount = [in collectionView:cv numberOfItemsInSection:ip.section];
    }
    if (ip.item == innerCount) {
        return [cv dequeueReusableCellWithReuseIdentifier:@"DVMoreCell" forIndexPath:ip];
    }
    if (in && [in respondsToSelector:@selector(collectionView:cellForItemAtIndexPath:)]) {
        return [in collectionView:cv cellForItemAtIndexPath:ip];
    }
    return [cv dequeueReusableCellWithReuseIdentifier:@"DVMoreCell" forIndexPath:ip];
}

- (id)forwardingTargetForSelector:(SEL)aSelector {
    if (self.inner && [self.inner respondsToSelector:aSelector]) return self.inner;
    return nil;
}

@end

#pragma mark - delegate 包装

@interface DVMoreDelegateProxy : NSObject <UICollectionViewDelegate>
@property (nonatomic, weak) id<UICollectionViewDelegate> inner;
@end

@implementation DVMoreDelegateProxy

- (BOOL)respondsToSelector:(SEL)aSelector {
    if (aSelector == @selector(collectionView:didSelectItemAtIndexPath:)) return YES;
    if (self.inner && [self.inner respondsToSelector:aSelector]) return YES;
    return [super respondsToSelector:aSelector];
}

- (void)collectionView:(UICollectionView *)cv didSelectItemAtIndexPath:(NSIndexPath *)ip {
    id<UICollectionViewDataSource> ds = cv.dataSource;
    NSInteger innerCount = 0;
    if ([ds respondsToSelector:@selector(collectionView:numberOfItemsInSection:)]) {
        innerCount = [ds collectionView:cv numberOfItemsInSection:ip.section] - 1;
    }
    if (ip.item == innerCount) {
        [cv deselectItemAtIndexPath:ip animated:YES];
        UIViewController *host = cv.window.rootViewController;
        while (host.presentedViewController) host = host.presentedViewController;
        [DVMenuController openSettingsFrom:host];
        return;
    }
    id<UICollectionViewDelegate> in = self.inner;
    if (in && [in respondsToSelector:@selector(collectionView:didSelectItemAtIndexPath:)]) {
        [in collectionView:cv didSelectItemAtIndexPath:ip];
    }
}

- (id)forwardingTargetForSelector:(SEL)aSelector {
    if (self.inner && [self.inner respondsToSelector:aSelector]) return self.inner;
    return nil;
}

@end

#pragma mark - 注入器

@implementation DVMoreInjector

+ (void)installInto:(UIViewController *)vc {
    if (!vc || !vc.view) return;
    if (objc_getAssociatedObject(vc, kDVMoreDSKey) ||
        objc_getAssociatedObject(vc, kDVMoreDGKey)) return;

    UICollectionView *cv = [self findCollectionViewIn:vc.view depth:0];
    if (!cv) {
        NSLog(@"[豆包语音] MoreVC(%@) 里没找到 UICollectionView",
              NSStringFromClass([vc class]));
        return;
    }
    if (objc_getAssociatedObject(cv, kDVMoreDSKey)) return;

    [cv registerClass:[DVMoreCell class] forCellWithReuseIdentifier:@"DVMoreCell"];

    // 剥掉已经套上去的 proxy，避免重复包装
    id<UICollectionViewDataSource> ds = cv.dataSource;
    if ([ds isKindOfClass:[DVMoreDataSourceProxy class]]) {
        ds = [(DVMoreDataSourceProxy *)ds inner];
    }

    DVMoreDataSourceProxy *dproxy = [DVMoreDataSourceProxy new];
    dproxy.inner = ds;
    cv.dataSource = dproxy;
    objc_setAssociatedObject(cv, kDVMoreDSKey, dproxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    id<UICollectionViewDelegate> dg = cv.delegate;
    if ([dg isKindOfClass:[DVMoreDelegateProxy class]]) {
        dg = [(DVMoreDelegateProxy *)dg inner];
    }
    DVMoreDelegateProxy *gproxy = [DVMoreDelegateProxy new];
    gproxy.inner = dg;
    cv.delegate = gproxy;
    objc_setAssociatedObject(cv, kDVMoreDGKey, gproxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    [cv reloadData];
    NSLog(@"[豆包语音] 加号面板已插入入口");
}

+ (UICollectionView *)findCollectionViewIn:(UIView *)view depth:(NSInteger)depth {
    if (!view || depth > 6) return nil;
    if ([view isKindOfClass:[UICollectionView class]]) return (UICollectionView *)view;
    for (UIView *sub in view.subviews) {
        UICollectionView *found = [self findCollectionViewIn:sub depth:depth + 1];
        if (found) return found;
    }
    return nil;
}

@end
