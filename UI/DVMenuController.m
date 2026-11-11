#import "DVMenuController.h"
#import "DVHUD.h"
#import "../TTS/DVTTSEngine.h"
#import "../Prefs/DVSettingsController.h"

// 整个微信进程只用一个引擎，避免两次朗读抢 AVAudioSession
static DVTTSEngine *gDVEngine = nil;

@implementation DVMenuController

+ (DVTTSEngine *)engine {
    if (!gDVEngine) gDVEngine = [DVTTSEngine new];
    return gDVEngine;
}

+ (void)readText:(NSString *)text {
    NSString *t = [text stringByTrimmingCharactersInSet:
                      [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (t.length == 0) {
        [DVHUD showError:@"没有可朗读的文字"];
        return;
    }
    [[self engine] speak:t
        onStatus:^(NSString *st) { [DVHUD show:st]; }
        onError:^(NSString *msg) { [DVHUD showError:msg]; }
        onFinish:^{ [DVHUD show:@"播完了"]; }];
}

+ (void)stopSpeaking {
    [gDVEngine stop];
    [DVHUD show:@"已停止"];
}

+ (void)openSettingsFrom:(UIViewController *)host {
    if (!host) {
        [DVHUD showError:@"找不到可用的界面"];
        return;
    }
    DVSettingsController *vc = [DVSettingsController new];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    [host presentViewController:nav animated:YES completion:nil];
}

+ (void)presentForText:(NSString *)text host:(UIViewController *)host {
    if (!host) return;

    NSString *trimmed = [(text ?: @"") stringByTrimmingCharactersInSet:
                            [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0) {
        [DVHUD showError:@"这段文字是空的"];
        return;
    }

    NSString *preview = trimmed.length > 40
        ? [[trimmed substringToIndex:40] stringByAppendingString:@"…"]
        : trimmed;
    NSString *title = [NSString stringWithFormat:@"共 %lu 字", (unsigned long)trimmed.length];

    UIAlertController *sheet =
        [UIAlertController alertControllerWithTitle:title
                                            message:preview
                                     preferredStyle:UIAlertControllerStyleActionSheet];

    NSString *payload = [trimmed copy];

    [sheet addAction:[UIAlertAction actionWithTitle:@"🔊 朗读这段"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *a) {
        [DVMenuController readText:payload];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:@"⏹ 停止朗读"
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction *a) {
        [DVMenuController stopSpeaking];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:@"⚙️ 豆包语音设置"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *a) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [DVMenuController openSettingsFrom:host];
        });
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:@"取消"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        sheet.popoverPresentationController.sourceView = host.view;
        sheet.popoverPresentationController.sourceRect =
            CGRectMake(host.view.bounds.size.width / 2,
                       host.view.bounds.size.height / 2, 1, 1);
        sheet.popoverPresentationController.permittedArrowDirections = 0;
    }

    [host presentViewController:sheet animated:YES completion:nil];
}

@end
