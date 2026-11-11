#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

%ctor {
    @autoreleasepool {
        NSLog(@"[豆包语音] 空壳版已加载 pid=%d", getpid());
    }
}
