#import "DVAudioPlayer.h"
#import <AVFoundation/AVFoundation.h>

@implementation DVAudioPlayer {
    AVAudioEngine *_engine;
    AVAudioPlayerNode *_node;
    AVAudioFormat *_format;
    BOOL _started;
}

- (instancetype)initWithSampleRate:(double)rate {
    if ((self = [super init])) {
        _format = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatInt16
                                                   sampleRate:rate
                                                     channels:1
                                                  interleaved:YES];
        _engine = [AVAudioEngine new];
        _node = [AVAudioPlayerNode new];
        [_engine attachNode:_node];
        [_engine connect:_node to:_engine.mainMixerNode format:_format];
    }
    return self;
}

- (void)start {
    if (_started) return;
    _started = YES;

    NSError *err = nil;
    AVAudioSession *as = [AVAudioSession sharedInstance];
    [as setCategory:AVAudioSessionCategoryPlayback
        withOptions:AVAudioSessionCategoryOptionDuckOthers
              error:&err];
    [as setActive:YES error:&err];
    if (err) NSLog(@"[豆包语音] audio session: %@", err);

    err = nil;
    [_engine startAndReturnError:&err];
    if (err) {
        // 微信可能占着 session，重试一次
        NSLog(@"[豆包语音] engine start failed: %@", err);
        [as setActive:NO
            withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation
                  error:nil];
        [as setActive:YES error:nil];
        [_engine startAndReturnError:&err];
    }
    [_node play];
}

- (void)appendPCM:(NSData *)pcm {
    if (pcm.length < 2) return;
    AVAudioFrameCount frames = (AVAudioFrameCount)(pcm.length / 2);
    if (frames == 0) return;

    AVAudioPCMBuffer *buf = [[AVAudioPCMBuffer alloc] initWithPCMFormat:_format
                                                         frameCapacity:frames];
    if (!buf || !buf.int16ChannelData) return;
    buf.frameLength = frames;
    memcpy(buf.int16ChannelData[0], pcm.bytes, pcm.length);
    [_node scheduleBuffer:buf completionHandler:nil];
}

- (void)finish {
    __weak typeof(self) weakSelf = self;
    AVAudioPCMBuffer *empty = [[AVAudioPCMBuffer alloc] initWithPCMFormat:_format frameCapacity:0];
    [_node scheduleBuffer:empty
        completionCallbackType:AVAudioPlayerNodeCompletionDataPlayedBack
        completionHandler:^(AVAudioPlayerNodeCompletionCallbackType t) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (self && self.onDrained) self.onDrained();
        });
    }];
}

- (void)stop {
    if (!_started) return;
    _started = NO;
    [_node stop];
    [_engine stop];
    [[AVAudioSession sharedInstance] setActive:NO
        withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation
              error:nil];
}

@end
