#import <UIKit/UIKit.h>

@interface DVMenuController : NSObject
+ (void)presentForText:(NSString *)text host:(UIViewController *)host;
+ (void)readText:(NSString *)text;
+ (void)stopSpeaking;
+ (void)openSettingsFrom:(UIViewController *)host;
@end
