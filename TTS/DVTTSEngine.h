#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, DVEngineState) {
    DVEngineIdle = 0,
    DVEngineConnecting,
    DVEngineSynthesizing,
    DVEngineError,
};

@interface DVTTSEngine : NSObject
- (void)speak:(NSString *)text
     onStatus:(void (^)(NSString *status))status
      onError:(void (^)(NSString *msg))onError
     onFinish:(void (^)(void))onFinish;
- (void)stop;
@property (nonatomic, readonly) DVEngineState state;
@end
