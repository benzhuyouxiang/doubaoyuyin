#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#import "Prefs/DVStore.h"
#import "TTS/DVProtocol.h"
#import "TTS/DVTextChunker.h"
#import "UI/DVHUD.h"

%ctor {
    @autoreleasepool {
        NSLog(@"[豆包语音] 第3轮开始 pid=%d", getpid());
        [DVHUD show:@"豆包语音已就绪"];
        NSLog(@"[豆包语音] 第3轮结束");
    }
}
