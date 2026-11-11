#import <Foundation/Foundation.h>
@interface DVTextChunker : NSObject
+ (NSArray<NSString *> *)split:(NSString *)text maxLength:(NSUInteger)max;
@end
