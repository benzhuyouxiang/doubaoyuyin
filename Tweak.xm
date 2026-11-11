#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#import "Prefs/DVStore.h"

%ctor {
    @autoreleasepool {
        NSLog(@"[豆包语音] 第1轮开始 pid=%d", getpid());

        DVStore *s = [DVStore shared];
        NSLog(@"[豆包语音] resourceId=%@ speaker=%@ rate=%d",
              s.resourceId, s.speaker, s.sampleRate);

        NSString *k = s.apiKey;
        NSLog(@"[豆包语音] apiKey 长度=%lu", (unsigned long)k.length);

        NSLog(@"[豆包语音] 第1轮结束");
    }
}
