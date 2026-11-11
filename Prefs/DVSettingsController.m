#import "DVSettingsController.h"
#import "DVStore.h"
#import "../UI/DVHUD.h"

@interface DVSettingsController () <UITableViewDataSource, UITableViewDelegate>
@end

@implementation DVSettingsController {
    UITableView *_table;
    NSArray<NSArray<NSString *> *> *_voices;
}

#pragma mark - 生命周期

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"豆包语音";
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];

    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"chevron.left"]
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(onBack)];

    _voices = @[
        @[@"2.0 冷御女声", @"zh_female_gaolengyujie_uranus_bigtts"],
        @[@"2.0 温柔女声", @"zh_female_wenrounvsheng_uranus_bigtts"],
        @[@"2.0 阳光男声", @"zh_male_yangguangnansheng_uranus_bigtts"],
        @[@"1.0 甜美女声", @"zh_female_tianmeixiaoyuan_moon_bigtts"],
        @[@"1.0 温柔男声", @"zh_male_wenrounansheng_moon_bigtts"],
    ];

    _table = [[UITableView alloc] initWithFrame:self.view.bounds
                                         style:UITableViewStyleInsetGrouped];
    _table.dataSource = self;
    _table.delegate = self;
    _table.backgroundColor = self.view.backgroundColor;
    _table.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _table.separatorInset = UIEdgeInsetsMake(0, 16, 0, 0);
    [self.view addSubview:_table];
}

- (void)onBack {
    if (self.navigationController.viewControllers.count > 1) {
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

#pragma mark - 数据源

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)section {
    return section == 0 ? 3 : 2;
}

- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)section {
    return section == 0 ? @"语音功能" : @"朗读";
}

- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)section {
    if (section == 0) {
        return @"音色和资源 ID 必须同代，配错会报 55000000";
    }
    return @"关闭长按朗读后，长按文字不再触发";
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    DVStore *st = [DVStore shared];

    if (ip.section == 0) {
        UITableViewCell *c = [self dv_valueCell:tv];
        if (ip.row == 0) {
            c.textLabel.text = @"音色设置";
            c.detailTextLabel.text = [NSString stringWithFormat:@"%@ ›",
                                     [self dv_shortVoiceName:st.speaker]];
        } else if (ip.row == 1) {
            c.textLabel.text = @"资源 ID";
            c.detailTextLabel.text = [NSString stringWithFormat:@"%@ ›", st.resourceId];
        } else {
            c.textLabel.text = @"API Key";
            c.detailTextLabel.text = st.apiKey.length ? @"已保存 ›" : @"未填 ›";
        }
        return c;
    }

    BOOL on;
    if (ip.row == 0) {
        on = DVEnableLongPress();
    } else {
        on = DVStreamPlay();
    }
    NSString *title = ip.row == 0 ? @"启用长按朗读" : @"启用边合成边播";
    return [self dv_switchCell:tv title:title on:on];
}

- (UITableViewCell *)dv_valueCell:(UITableView *)tv {
    UITableViewCell *c = [tv dequeueReusableCellWithIdentifier:@"val"];
    if (!c) {
        c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                   reuseIdentifier:@"val"];
        c.textLabel.font = [UIFont systemFontOfSize:16];
        c.detailTextLabel.font = [UIFont systemFontOfSize:15];
        c.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    }
    return c;
}

- (UITableViewCell *)dv_switchCell:(UITableView *)tv title:(NSString *)title on:(BOOL)on {
    UITableViewCell *c = [tv dequeueReusableCellWithIdentifier:@"sw"];
    if (!c) {
        c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                   reuseIdentifier:@"sw"];
        c.textLabel.font = [UIFont systemFontOfSize:16];
        c.selectionStyle = UITableViewCellSelectionStyleNone;
        UISwitch *sw = [[UISwitch alloc] init];
        sw.onTintColor = [UIColor colorWithRed:0.09 green:0.73 blue:0.35 alpha:1.0];
        c.accessoryView = sw;
    }
    c.textLabel.text = title;
    UISwitch *sw = (UISwitch *)c.accessoryView;
    sw.on = on;
    [sw removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
    [sw addTarget:self action:@selector(onSwitchChanged:)
        forControlEvents:UIControlEventValueChanged];
    return c;
}

#pragma mark - 交互

- (void)onSwitchChanged:(UISwitch *)sw {
    UIView *v = sw.superview;
    while (v && ![v isKindOfClass:[UITableViewCell class]]) v = v.superview;
    if (!v) return;
    NSIndexPath *ip = [_table indexPathForCell:(UITableViewCell *)v];
    if (!ip || ip.section != 1) return;

    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    NSString *key = (ip.row == 0) ? @"dv.enableLongPress" : @"dv.streamPlay";
    [d setBool:sw.isOn forKey:key];
    [d synchronize];
    [DVHUD show:sw.isOn ? @"已开启" : @"已关闭"];
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    if (ip.section != 0) return;

    if (ip.row == 0)      [self dv_pickVoice];
    else if (ip.row == 1) [self dv_pickResource];
    else                  [self dv_editKey];
}

#pragma mark - 三个设置项

- (void)dv_pickVoice {
    DVStore *st = [DVStore shared];
    UIAlertController *sheet =
        [UIAlertController alertControllerWithTitle:@"选择音色"
                                            message:@"2.0 音色需要资源 ID 为 seed-tts-2.0"
                                     preferredStyle:UIAlertControllerStyleActionSheet];

    for (NSArray<NSString *> *pair in _voices) {
        NSString *title = [NSString stringWithFormat:@"%@%@", pair[0],
                           [st.speaker isEqualToString:pair[1]] ? @"  ✓" : @""];
        [sheet addAction:[UIAlertAction actionWithTitle:title
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *a) {
            st.speaker = pair[1];
            [self dv_checkMatch];
            [_table reloadData];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消"
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];
    [self dv_anchorPopover:sheet];
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)dv_pickResource {
    DVStore *st = [DVStore shared];
    UIAlertController *sheet =
        [UIAlertController alertControllerWithTitle:@"资源 ID"
                                            message:@"要和音色同代"
                                     preferredStyle:UIAlertControllerStyleActionSheet];

    NSArray<NSArray<NSString *> *> *options = @[
        @[@"seed-tts-2.0", @"2.0 大模型（uranus 音色）"],
        @[@"seed-icl-2.0", @"1.0 大模型（moon 音色）"],
    ];
    for (NSArray<NSString *> *o in options) {
        NSString *title = [NSString stringWithFormat:@"%@%@", o[1],
                           [st.resourceId isEqualToString:o[0]] ? @"  ✓" : @""];
        [sheet addAction:[UIAlertAction actionWithTitle:title
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *a) {
            st.resourceId = o[0];
            [self dv_checkMatch];
            [_table reloadData];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消"
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];
    [self dv_anchorPopover:sheet];
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)dv_editKey {
    DVStore *st = [DVStore shared];
    UIAlertController *al =
        [UIAlertController alertControllerWithTitle:@"API Key"
                                            message:@"从火山引擎控制台复制"
                                     preferredStyle:UIAlertControllerStyleAlert];
    [al addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.text = st.apiKey;
        tf.placeholder = @"粘贴 X-Api-Key";
        tf.autocorrectionType = UITextAutocorrectionTypeNo;
        tf.autocapitalizationType = UITextAutocapitalizationTypeNone;
        tf.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    [al addAction:[UIAlertAction actionWithTitle:@"保存"
                                          style:UIAlertActionStyleDefault
                                        handler:^(UIAlertAction *a) {
        NSString *v = al.textFields.firstObject.text ?: @"";
        v = [v stringByTrimmingCharactersInSet:
                [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        st.apiKey = v;
        [DVHUD show:v.length ? @"已保存" : @"已清空"];
        [_table reloadData];
    }]];
    [al addAction:[UIAlertAction actionWithTitle:@"取消"
                                          style:UIAlertActionStyleCancel
                                        handler:nil]];
    [self presentViewController:al animated:YES completion:nil];
}

#pragma mark - 工具

- (void)dv_anchorPopover:(UIAlertController *)sheet {
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        sheet.popoverPresentationController.sourceView = self.view;
        sheet.popoverPresentationController.sourceRect =
            CGRectMake(self.view.bounds.size.width / 2,
                       self.view.bounds.size.height / 2, 1, 1);
        sheet.popoverPresentationController.permittedArrowDirections = 0;
    }
}

- (void)dv_checkMatch {
    DVStore *st = [DVStore shared];
    BOOL ridIs20 = [st.resourceId isEqualToString:@"seed-tts-2.0"];
    BOOL voiceIs20 = [st.speaker containsString:@"uranus"];
    if (ridIs20 != voiceIs20) {
        [DVHUD showError:@"音色和资源 ID 不匹配，会报 55000000"];
    }
}

- (NSString *)dv_shortVoiceName:(NSString *)speakerId {
    for (NSArray<NSString *> *pair in _voices) {
        if ([pair[1] isEqualToString:speakerId]) return pair[0];
    }
    return speakerId.length > 12 ? [speakerId substringToIndex:12] : speakerId;
}

@end
