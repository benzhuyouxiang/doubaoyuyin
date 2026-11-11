#import <Foundation/Foundation.h>

typedef NS_ENUM(uint8_t, DVMsgType) {
    DVMsgTypeFullClientRequest  = 1,
    DVMsgTypeAudioOnlyClient    = 2,
    DVMsgTypeFullServerResponse = 9,
    DVMsgTypeAudioOnlyServer    = 11,
    DVMsgTypeFrontEndResult     = 12,
    DVMsgTypeError              = 15,
};

typedef NS_ENUM(uint8_t, DVFlag) {
    DVFlagNoSeq       = 0,
    DVFlagPositiveSeq = 1,
    DVFlagLastNoSeq   = 2,
    DVFlagNegativeSeq = 3,
    DVFlagWithEvent   = 4,
};

typedef NS_ENUM(int32_t, DVEvent) {
    DVEventStartConnection     = 1,
    DVEventFinishConnection    = 2,
    DVEventConnectionStarted   = 50,
    DVEventConnectionFailed    = 51,
    DVEventConnectionFinished  = 52,
    DVEventStartSession        = 100,
    DVEventCancelSession       = 101,
    DVEventFinishSession       = 102,
    DVEventSessionStarted      = 150,
    DVEventSessionCanceled     = 151,
    DVEventSessionFinished     = 152,
    DVEventSessionFailed       = 153,
    DVEventUsageResponse       = 154,
    DVEventTaskRequest         = 200,
    DVEventTTSSentenceStart    = 350,
    DVEventTTSSentenceEnd      = 351,
    DVEventTTSResponse         = 352,
    DVEventTTSSubtitle         = 364,
};

@interface DVMessage : NSObject
@property (nonatomic) uint8_t type;
@property (nonatomic) uint8_t flag;
@property (nonatomic) int32_t event;
@property (nonatomic) int32_t errorCode;
@property (nonatomic, copy) NSString *sessionId;
@property (nonatomic, copy) NSString *connectId;
@property (nonatomic, copy) NSData *payload;
@end

@interface DVProtocol : NSObject
+ (NSData *)buildUpstream:(DVEvent)event sessionId:(NSString *)sid payload:(NSString *)json;
+ (DVMessage *)parseDownstream:(NSData *)data;
@end
