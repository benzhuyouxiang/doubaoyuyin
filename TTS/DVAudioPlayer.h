#import <Foundation/Foundation.h>

@interface DVAudioPlayer : NSObject
- (instancetype)initWithSampleRate:(double)rate;
- (void)start;
- (void)appendPCM:(NSData *)pcm;
- (void)finish;
- (void)stop;
@property (nonatomic, copy) void (^onDrained)(void);
@end
