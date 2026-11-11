#import <Foundation/Foundation.h>

@interface DVAudioPlayer : NSObject
- (nullable instancetype)initWithSampleRate:(double)rate NS_DESIGNATED_INITIALIZER;
- (void)start;
- (void)appendPCM:(NSData *)pcm;
- (void)finish;
- (void)stop;
@property (nonatomic, copy) void (^onDrained)(void);
@end
