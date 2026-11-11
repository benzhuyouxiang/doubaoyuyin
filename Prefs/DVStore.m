#import "DVStore.h"
#import <Security/Security.h>

static NSString *const kDVKeychainService = @"com.doubao.voice.wechat";

BOOL DVReadBool(NSString *key, BOOL defVal) {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    if ([d objectForKey:key] == nil) return defVal;
    return [d boolForKey:key];
}

BOOL DVEnableLongPress(void) { return DVReadBool(@"dv.enableLongPress", YES); }
BOOL DVStreamPlay(void)      { return DVReadBool(@"dv.streamPlay", YES); }

@implementation DVStore

+ (instancetype)shared {
    static DVStore *inst = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ inst = [DVStore new]; });
    return inst;
}

- (instancetype)init {
    if ((self = [super init])) {
        NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
        if (![d objectForKey:@"dv.resourceId"]) {
            [d setObject:@"seed-tts-2.0" forKey:@"dv.resourceId"];
        }
        if (![d objectForKey:@"dv.speaker"]) {
            [d setObject:@"zh_female_gaolengyujie_uranus_bigtts" forKey:@"dv.speaker"];
        }
        if (![d objectForKey:@"dv.sampleRate"]) {
            [d setObject:@24000 forKey:@"dv.sampleRate"];
        }
        [d synchronize];
    }
    return self;
}

- (NSString *)resourceId {
    return [[NSUserDefaults standardUserDefaults] stringForKey:@"dv.resourceId"];
}
- (void)setResourceId:(NSString *)v {
    [[NSUserDefaults standardUserDefaults] setObject:(v ?: @"seed-tts-2.0")
                                              forKey:@"dv.resourceId"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSString *)speaker {
    return [[NSUserDefaults standardUserDefaults] stringForKey:@"dv.speaker"];
}
- (void)setSpeaker:(NSString *)v {
    [[NSUserDefaults standardUserDefaults] setObject:(v ?: @"zh_female_gaolengyujie_uranus_bigtts")
                                              forKey:@"dv.speaker"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (int)sampleRate {
    NSInteger n = [[NSUserDefaults standardUserDefaults] integerForKey:@"dv.sampleRate"];
    return n > 0 ? (int)n : 24000;
}
- (void)setSampleRate:(int)v {
    [[NSUserDefaults standardUserDefaults] setInteger:v forKey:@"dv.sampleRate"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark - Keychain

- (NSString *)apiKey {
    NSDictionary *q = @{
        (__bridge id)kSecClass:       (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: kDVKeychainService,
        (__bridge id)kSecReturnData:  @YES,
        (__bridge id)kSecMatchLimit:  (__bridge id)kSecMatchLimitOne,
    };
    CFTypeRef result = NULL;
    OSStatus st = SecItemCopyMatching((__bridge CFDictionaryRef)q, &result);
    if (st == errSecSuccess && result) {
        NSData *data = (__bridge_transfer NSData *)result;
        NSString *s = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        return s ?: @"";
    }
    return @"";
}

- (void)setApiKey:(NSString *)v {
    NSDictionary *q = @{
        (__bridge id)kSecClass:       (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: kDVKeychainService,
    };
    SecItemDelete((__bridge CFDictionaryRef)q);
    if (v.length == 0) return;

    NSDictionary *add = @{
        (__bridge id)kSecClass:       (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: kDVKeychainService,
        (__bridge id)kSecAttrAccount: @"apiKey",
        (__bridge id)kSecValueData:   [v dataUsingEncoding:NSUTF8StringEncoding],
    };
    OSStatus st = SecItemAdd((__bridge CFDictionaryRef)add, NULL);
    if (st != errSecSuccess) {
        NSLog(@"[豆包语音] Keychain 写入失败: %d", (int)st);
    }
}

@end
