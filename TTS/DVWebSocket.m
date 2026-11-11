#import "DVWebSocket.h"

@interface DVWebSocket () <NSURLSessionWebSocketDelegate, NSURLSessionDataDelegate>
@end

@implementation DVWebSocket {
    NSURLSession *_session;
    NSURLSessionWebSocketTask *_task;
    __weak id<DVWebSocketDelegate> _delegate;
    BOOL _closed;
}

- (instancetype)initWithURL:(NSString *)url headers:(NSDictionary<NSString *, NSString *> *)headers {
    if ((self = [super init])) {
        _logId = @"";
        NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
        [headers enumerateKeysAndObjectsUsingBlock:^(NSString *k, NSString *v, BOOL *stop) {
            [req setValue:v forHTTPHeaderField:k];
        }];
        NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration defaultSessionConfiguration];
        cfg.timeoutIntervalForRequest = 20.0;
        _session = [NSURLSession sessionWithConfiguration:cfg delegate:self delegateQueue:nil];
        _task = [_session webSocketTaskWithRequest:req];
    }
    return self;
}

- (void)connectWithDelegate:(id<DVWebSocketDelegate>)delegate {
    _delegate = delegate;
    [_task resume];
    [self dvReadLoop];
}

- (void)dvReadLoop {
    __weak typeof(self) weakSelf = self;
    [_task receiveMessageWithCompletionHandler:^(NSURLSessionWebSocketMessage *msg, NSError *err) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || self->_closed) return;
        if (err) {
            id<DVWebSocketDelegate> d = self->_delegate;
            if (d) [d dvWSDidFail:err.localizedDescription];
            return;
        }
        if (msg.type == NSURLSessionWebSocketMessageTypeData && msg.data) {
            id<DVWebSocketDelegate> d = self->_delegate;
            if (d) [d dvWSDidReceive:msg.data];
        }
        [self dvReadLoop];
    }];
}

- (void)send:(NSData *)data {
    if (_closed || !data) return;
    NSURLSessionWebSocketMessage *m = [[NSURLSessionWebSocketMessage alloc] initWithData:data];
    [_task sendMessage:m completionHandler:^(NSError *err) {
        if (err) NSLog(@"[豆包语音] send error: %@", err);
    }];
}

- (void)close {
    _closed = YES;
    [_task cancelWithCloseCode:NSURLSessionWebSocketCloseCodeNormalClosure reason:nil];
    [_session invalidateAndCancel];
}

#pragma mark - NSURLSessionWebSocketDelegate

- (void)URLSession:(NSURLSession *)session
      webSocketTask:(NSURLSessionWebSocketTask *)task
didOpenWithProtocol:(NSString *)protocol {
    id<DVWebSocketDelegate> d = _delegate;
    if (d) [d dvWSDidOpenWithLogId:_logId ?: @""];
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error {
    if (_closed) return;
    id<DVWebSocketDelegate> d = _delegate;
    if (error) {
        if (d) [d dvWSDidFail:error.localizedDescription];
    } else if (d) {
        [d dvWSDidClose];
    }
}

#pragma mark - 抓 X-Tt-Logid

- (void)URLSession:(NSURLSession *)session
             task:(NSURLSessionTask *)task
 willPerformHTTPRedirection:(NSHTTPURLResponse *)response
        newRequest:(NSURLRequest *)request
 completionHandler:(void (^)(NSURLRequest *))completionHandler {
    NSString *lid = response.allHeaderFields[@"X-Tt-Logid"];
    if (lid.length) _logId = lid;
    completionHandler(request);
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSString *lid = ((NSHTTPURLResponse *)response).allHeaderFields[@"X-Tt-Logid"];
        if (lid.length) _logId = lid;
    }
    completionHandler(NSURLSessionResponseAllow);
}

@end
