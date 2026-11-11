#import <UIKit/UIKit.h>

@interface DVHUD : NSObject
+ (void)show:(NSString *)text;
+ (void)showError:(NSString *)text;
+ (void)hide;
@end
