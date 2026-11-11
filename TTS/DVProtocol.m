#import "DVProtocol.h"

@implementation DVMessage
@end

static void dvAppendI32(NSMutableData *d, int32_t v) {
    uint32_t u = (uint32_t)v;
    uint8_t b[4] = { (uint8_t)((u >> 24) & 0xFF), (uint8_t)((u >> 16) & 0xFF),
                     (uint8_t)((u >> 8) & 0xFF),  (uint8_t)(u & 0xFF) };
    [d appendBytes:b length:4];
}

static int32_t dvReadU32(const uint8_t *p) {
    return (int32_t)(((uint32_t)p[0] << 24) | ((uint32_t)p[1] << 16) |
                     ((uint32_t)p[2] << 8)  | (uint32_t)p[3]);
}

static BOOL dvClientHasNoSession(DVEvent e) {
    return e == DVEventStartConnection || e == DVEventFinishConnection;
}

static BOOL dvServerHasNoSession(DVEvent e) {
    return e == DVEventStartConnection || e == DVEventFinishConnection ||
           e == DVEventConnectionStarted || e == DVEventConnectionFailed ||
           e == DVEventConnectionFinished;
}

static BOOL dvIsConnectIdEvent(DVEvent e) {
    return e == DVEventConnectionStarted || e == DVEventConnectionFailed ||
           e == DVEventConnectionFinished;
}

@implementation DVProtocol

+ (NSData *)buildUpstream:(DVEvent)event sessionId:(NSString *)sid payload:(NSString *)json {
    NSMutableData *out = [NSMutableData data];
    uint8_t head[4] = { 0x11, (uint8_t)((DVMsgTypeFullClientRequest << 4) | DVFlagWithEvent), 0x10, 0x00 };
    [out appendBytes:head length:4];
    dvAppendI32(out, event);
    if (!dvClientHasNoSession(event)) {
        NSData *s = [(sid ?: @"") dataUsingEncoding:NSUTF8StringEncoding];
        dvAppendI32(out, (int32_t)s.length);
        [out appendData:s];
    }
    NSData *p = [(json ?: @"") dataUsingEncoding:NSUTF8StringEncoding];
    dvAppendI32(out, (int32_t)p.length);
    [out appendData:p];
    return out;
}

+ (DVMessage *)parseDownstream:(NSData *)data {
    DVMessage *m = [DVMessage new];
    m.payload = [NSData data];
    if (data.length < 4) return m;
    const uint8_t *b = (const uint8_t *)data.bytes;
    NSInteger pos = (b[0] & 0x0F) * 4;
    m.type = (b[1] >> 4) & 0x0F;
    m.flag = b[1] & 0x0F;

    if (m.type == DVMsgTypeError) {
        if (pos + 4 > (NSInteger)data.length) return m;
        m.errorCode = dvReadU32(b + pos); pos += 4;
    } else if (m.flag == DVFlagPositiveSeq || m.flag == DVFlagNegativeSeq) {
        pos += 4;
    }

    if (m.flag == DVFlagWithEvent) {
        if (pos + 4 > (NSInteger)data.length) return m;
        m.event = dvReadU32(b + pos); pos += 4;

        if (!dvServerHasNoSession((DVEvent)m.event)) {
            if (pos + 4 > (NSInteger)data.length) return m;
            int32_t n = dvReadU32(b + pos); pos += 4;
            if (n > 0 && pos + n <= (NSInteger)data.length) {
                m.sessionId = [[NSString alloc] initWithBytes:b + pos length:n encoding:NSUTF8StringEncoding];
                pos += n;
            }
        }
        if (dvIsConnectIdEvent((DVEvent)m.event)) {
            if (pos + 4 > (NSInteger)data.length) return m;
            int32_t n = dvReadU32(b + pos); pos += 4;
            if (n > 0 && pos + n <= (NSInteger)data.length) {
                m.connectId = [[NSString alloc] initWithBytes:b + pos length:n encoding:NSUTF8StringEncoding];
                pos += n;
            }
        }
    }

    if (pos + 4 <= (NSInteger)data.length) {
        int32_t n = dvReadU32(b + pos); pos += 4;
        if (n > 0 && pos + n <= (NSInteger)data.length) {
            m.payload = [data subdataWithRange:NSMakeRange(pos, n)];
        }
    }
    return m;
}

@end
