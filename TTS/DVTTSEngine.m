#import "DVTTSEngine.h"
#import "DVProtocol.h"
#import "DVWebSocket.h"
#import "DVAudioPlayer.h"
#import "DVTextChunker.h"
#import "../Prefs/DVStore.h"

static NSString *const kDVEndpoint = @"wss://openspeech.bytedance.com/api/v3/tts/bidirection";

@interface DVTTSEngine () <DVWebSocketDelegate>
@end

@implementation DVTTSEngine {
    DVWebSocket *_ws;
    DVAudioPlayer *_player;
    NSArray<NSString *> *_chunks;
    NSUInteger _sentIndex;
    NSString *_sessionId;
    NSString *_speaker;
    int _sampleRate;
    BOOL _active;

    void (^_statusBlock)(NSString *);
    void (^_errorBlock)(NSString *);
    void (^_finishBlock)(void);
}

- (DVEngineState)state {
    if (!_active) return DVEngineIdle;
    if (!_sessionId) return DVEngineConnecting;
    return DVEngineSynthesizing;
}

- (void)speak:(NSString *)text
     onStatus:(void (^)(NSString *))status
      onError:(void (^)(NSString *))onError
     onFinish:(void (^)(void))onFinish {
    [self stop];

    _statusBlock = [status copy];
    _errorBlock = [onError copy];
    _finishBlock = [onFinish copy];

    DVStore *s = [DVStore shared];
    NSString *key = [s apiKey];
    if (key.length == 0) {
        [self fail:@"先去「豆包语音」设置里填 API Key"];
        return;
    }

    NSString *clean = [text stringByTrimmingCharactersInSet:
                          [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (clean.length == 0) {
        [self fail:@"文字是空的"];
        return;
    }

    _active = YES;
    _speaker = [s speaker];
    _sampleRate = [s sampleRate];
    _chunks = [DVTextChunker split:clean maxLength:90];
    if (_chunks.count == 0) {
        [self fail:@"切段后没有内容"];
        return;
    }
    _sentIndex = 0;
    _sessionId = nil;

    NSMutableDictionary *h = [NSMutableDictionary dictionary];
    h[@"X-Api-Key"] = key;
    h[@"X-Api-Resource-Id"] = [s resourceId];
    h[@"X-Api-Connect-Id"] = [NSUUID UUID].UUIDString;
    h[@"X-Control-Require-Usage-Tokens-Return"] = @"*";

    _player = [[DVAudioPlayer alloc] initWithSampleRate:(double)_sampleRate];
    __weak typeof(self) weakSelf = self;
    _player.onDrained = ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (self) [self finishAll];
    };

    _ws = [[DVWebSocket alloc] initWithURL:kDVEndpoint headers:h];
    [_ws connectWithDelegate:self];
    [self status:@"连接中…"];
}

#pragma mark - 状态回调

- (void)status:(NSString *)text {
    void (^b)(NSString *) = _statusBlock;
    if (!b) return;
    dispatch_async(dispatch_get_main_queue(), ^{ b(text); });
}

- (void)fail:(NSString *)msg {
    _active = NO;
    [_ws close];
    _ws = nil;
    [_player stop];
    _player = nil;
    void (^b)(NSString *) = _errorBlock;
    if (b) dispatch_async(dispatch_get_main_queue(), ^{ b(msg); });
}

- (void)finishAll {
    _active = NO;
    [_ws close];
    _ws = nil;
    [_player stop];
    _player = nil;
    void (^f)(void) = _finishBlock;
    if (f) dispatch_async(dispatch_get_main_queue(), ^{ f(); });
    [self status:@"播完了"];
}

- (void)stop {
    _active = NO;
    [_ws close];
    _ws = nil;
    [_player stop];
    _player = nil;
    _sessionId = nil;
    _statusBlock = nil;
    _errorBlock = nil;
    _finishBlock = nil;
}

#pragma mark - DVWebSocketDelegate

- (void)dvWSDidOpenWithLogId:(NSString *)logId {
    [_ws send:[DVProtocol buildUpstream:DVEventStartConnection sessionId:nil payload:@"{}"]];
    [self status:(logId.length ? [NSString stringWithFormat:@"已建连 %@", logId] : @"已建连")];
}

- (void)dvWSDidReceive:(NSData *)data {
    DVMessage *m = [DVProtocol parseDownstream:data];

    if (m.type == DVMsgTypeError) {
        NSString *t = [[NSString alloc] initWithData:m.payload encoding:NSUTF8StringEncoding];
        [self fail:[NSString stringWithFormat:@"服务端错误 code=%d · %@", m.errorCode, t ?: @""]];
        return;
    }

    switch (m.event) {
        case DVEventConnectionStarted:
            [self startSession];
            break;

        case DVEventConnectionFailed: {
            NSString *t = [[NSString alloc] initWithData:m.payload encoding:NSUTF8StringEncoding];
            [self fail:[NSString stringWithFormat:@"建连失败：%@", t ?: @"(无信息)"]];
            break;
        }

        case DVEventSessionStarted:
            [_player start];
            [self sendNextChunk];
            break;

        case DVEventSessionFailed:
        case DVEventSessionCanceled: {
            NSString *t = [[NSString alloc] initWithData:m.payload encoding:NSUTF8StringEncoding];
            [self fail:t.length ? t : @"会话失败"];
            break;
        }

        case DVEventTTSSentenceStart:
            [self status:@"合成中…"];
            break;

        case DVEventTTSResponse:
            if (m.payload.length) [_player appendPCM:m.payload];
            break;

        case DVEventUsageResponse: {
            NSString *t = [[NSString alloc] initWithData:m.payload encoding:NSUTF8StringEncoding];
            if (t.length) NSLog(@"[豆包语音] usage: %@", t);
            break;
        }

        case DVEventSessionFinished:
            [self sendFinishSession];
            [_player finish];
            [self status:@"合成完成"];
            break;

        default:
            break;
    }
}

- (void)dvWSDidFail:(NSString *)reason {
    if (_active) [self fail:[NSString stringWithFormat:@"网络：%@", reason ?: @"未知"]];
}

- (void)dvWSDidClose {
}

#pragma mark - 会话流程

- (void)startSession {
    _sessionId = [NSUUID UUID].UUIDString;

    NSDictionary *req = @{
        @"event": @(DVEventStartSession),
        @"req_params": @{
            @"speaker": _speaker,
            @"audio_params": @{ @"format": @"pcm", @"sample_rate": @(_sampleRate) }
        }
    };
    NSData *json = [NSJSONSerialization dataWithJSONObject:req options:0 error:nil];
    NSString *str = [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
    [_ws send:[DVProtocol buildUpstream:DVEventStartSession sessionId:_sessionId payload:str]];
    [self status:@"建会话…"];
}

- (void)sendNextChunk {
    if (!_active) return;

    if (_sentIndex >= _chunks.count) {
        [self sendFinishSession];
        return;
    }

    NSString *piece = _chunks[_sentIndex];
    _sentIndex++;

    NSDictionary *req = @{
        @"event": @(DVEventTaskRequest),
        @"req_params": @{
            @"speaker": _speaker,
            @"audio_params": @{ @"format": @"pcm", @"sample_rate": @(_sampleRate) },
            @"text": piece
        }
    };
    NSData *json = [NSJSONSerialization dataWithJSONObject:req options:0 error:nil];
    NSString *str = [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
    [_ws send:[DVProtocol buildUpstream:DVEventTaskRequest sessionId:_sessionId payload:str]];

    [self status:[NSString stringWithFormat:@"发送 %lu/%lu",
                  (unsigned long)_sentIndex, (unsigned long)_chunks.count]];

    if (_sentIndex < _chunks.count) {
        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.02 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (self && self->_active) [self sendNextChunk];
        });
    }
}

- (void)sendFinishSession {
    if (!_sessionId || !_ws) return;
    [_ws send:[DVProtocol buildUpstream:DVEventFinishSession sessionId:_sessionId payload:@"{}"]];
}

@end
