#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#import "Prefs/DVStore.h"
#import "TTS/DVProtocol.h"
#import "TTS/DVTextChunker.h"
#import "TTS/DVAudioPlayer.h"
#import "TTS/DVTTSEngine.h"
#import "UI/DVHUD.h"

static DVTTSEngine *gEngine = nil;

static void dv_round4_test(void) {
    @try {
        gEngine = [DVTTSEngine new];
        NSLog(@"[豆包语音] 引擎创建完成 state=%ld", (long)gEngine.state);

        DVAudioPlayer *p = [[DVAudioPlayer alloc] initWithSampleRate:24000.0];
        NSLog(@"[豆包语音] 播放器创建完成 %p", p);

        [DVHUD show:@"引擎就绪"];
    } @catch (NSException *e) {
        NSLog(@"[豆包语音] 第4轮异常: %@ @ %@", e.reason, e.callStackSymbols);
        [DVHUD showError:@"引擎创建失败"];
    }
}

%ctor {
    @autoreleasepool {
        NSLog(@"[豆包语音] 第4轮开始 pid=%d", getpid());
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            dv_round4_test();
        });
    }
}
