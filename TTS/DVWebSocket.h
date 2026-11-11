#import <Foundation/Foundation.h>

@protocol DVWebSocketDelegate <NSObject>
- (void)dvWSDidOpenWithLogId:(NSString *)logId;
- (void)dvWSDidReceive:(NSData *)data;
- (void)dvWSDidFail:(NSString *)reason;
- (void)dvWSDidClose;
@end

@interface DVWebSocket : NSObject
- (instancetype)initWithURL:(NSString *)url headers:(NSDictionary<NSString *, NSString *> *)headers;
- (void)connectWithDelegate:(id<DVWebSocketDelegate>)delegate;
- (void)send:(NSData *)data;
- (void)close;
@property (nonatomic, readonly, copy) NSString *logId;
@end
