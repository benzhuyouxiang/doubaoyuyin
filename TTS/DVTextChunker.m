#import "DVTextChunker.h"

@implementation DVTextChunker

+ (NSArray<NSString *> *)split:(NSString *)text maxLength:(NSUInteger)max {
    NSMutableArray<NSString *> *out = [NSMutableArray array];
    if (text.length == 0 || max == 0) return out;

    NSCharacterSet *ws = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    NSString *t = [text stringByTrimmingCharactersInSet:ws];
    if (t.length == 0) return out;

    NSCharacterSet *enders = [NSCharacterSet characterSetWithCharactersInString:@"。！？!?；;…\n"];
    NSMutableString *cur = [NSMutableString string];
    NSInteger i = 0, n = (NSInteger)t.length;

    while (i < n) {
        unichar c = [t characterAtIndex:i];
        [cur appendFormat:@"%C", c];
        i++;
        BOOL isEnd = [enders characterIsMember:c];
        BOOL over = cur.length >= max;
        if (isEnd || over) {
            NSString *piece = [cur stringByTrimmingCharactersInSet:ws];
            if (piece.length) [out addObject:piece];
            [cur setString:@""];
        }
    }
    NSString *tail = [cur stringByTrimmingCharactersInSet:ws];
    if (tail.length) [out addObject:tail];
    return out;
}

@end
