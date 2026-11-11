#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#import "Prefs/DVStore.h"
#import "TTS/DVProtocol.h"
#import "TTS/DVTextChunker.h"

%ctor {
    @autoreleasepool {
        NSLog(@"[豆包语音] 第2轮开始 pid=%d", getpid());

        NSData *d = [DVProtocol buildUpstream:DVEventStartConnection sessionId:nil payload:@"{}"];
        NSLog(@"[豆包语音] StartConnection 包长 %lu 字节", (unsigned long)d.length);

        const uint8_t *b = (const uint8_t *)d.bytes;
        if (d.length >= 12) {
            NSLog(@"[豆包语音] 前12字节 %02x %02x %02x %02x | %02x %02x %02x %02x | %02x %02x %02x %02x",
                  b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7], b[8], b[9], b[10], b[11]);
        }

        NSArray *pieces = [DVTextChunker split:@"你好。这是一段测试文字，用来验证切段逻辑是否正常！" maxLength:10];
        NSLog(@"[豆包语音] 切段结果 %lu 段: %@",
              (unsigned long)pieces.count, [pieces componentsJoinedByString:@" / "]);

        NSLog(@"[豆包语音] 第2轮结束");
    }
}
