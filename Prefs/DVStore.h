#import <Foundation/Foundation.h>

@interface DVStore : NSObject
+ (instancetype)shared;
@property (nonatomic, copy) NSString *apiKey;      // Keychain
@property (nonatomic, copy) NSString *resourceId;  // seed-tts-2.0 / seed-icl-2.0
@property (nonatomic, copy) NSString *speaker;
@property (nonatomic) int sampleRate;
@end

// 全局开关读取（Tweak 和设置页共用）
BOOL DVReadBool(NSString *key, BOOL defVal);
BOOL DVEnableLongPress(void);
BOOL DVStreamPlay(void);
