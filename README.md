# 豆包语音 for 微信（巨魔 / Theos Tweak）

微信里长按任意文字 → 弹菜单 → 念出来。设置页照锤子助手那种风格做，只有四项。

---

## 1. 功能

| 入口 | 位置 |
| --- | --- |
| **长按文字** | 聊天消息、朋友圈、公众号里，长按 0.5 秒 → 「🔊 朗读这段 / ⏹ 停止朗读 / ⚙️ 豆包语音设置」 |
| **加号面板** | 聊天框右边 ➕ → 面板最后一格橙红「声」图标 → 设置页 |
| **我页右上角** | 「我」页面右上角「豆包」按钮 → 设置页（保底入口） |

## 2. 设置页

照锤子助手「语音功能」那套风格：

```
语音功能
────────────────────────────
  音色设置          2.0 冷御女声 ›
  资源 ID           seed-tts-2.0 ›
  API Key           已保存 ›
  ────────────────────────
  音色和资源 ID 必须同代，配错会报 55000000

朗读
────────────────────────────
  启用长按朗读                [开关]
  启用边合成边播              [开关]
  ────────────────────────
  关闭长按朗读后，长按文字不再触发
```

- **音色设置 / 资源 ID / API Key** 点一下弹选择框
- **两个开关**实时存 NSUserDefaults，长按朗读是总开关

## 3. 编译（用 GitHub 免费 macOS 机器）

### 3.1 建仓库 + 传文件

1. <https://github.com/new> → 名字随便 → Private → Create
2. 点 **Add file → Upload files**
3. 打开资源管理器进到 `DoubaoVoiceWeChat2\` **里面**（地址栏显示 `...\DoubaoVoiceWeChat2`），Ctrl+A 全选：

```
Makefile
control
DoubaoVoiceWeChat.plist
Tweak.xm
TTS\
UI\
Prefs\
.github\
```

4. 全选拖进上传区 → **Commit changes**

> ⚠️ 拖的是文件夹**里面的内容**，不要连 `DoubaoVoiceWeChat2` 这层壳一起拖。
> 传完仓库根目录应该直接看到 `Makefile`。
> Windows 资源管理器默认隐藏 `.github`，要先在「查看」里勾「隐藏的项目」。

### 3.2 跑编译

1. 仓库顶部 **Actions** → 左侧 `build-dylib` → 右侧 **Run workflow** → 绿色按钮
2. 3~5 分钟，变绿勾

### 3.3 下载

进那条绿勾记录，滚到**页面最底部**，**Artifacts** 里：

| Artifact | 内容 |
| --- | --- |
| `DoubaoVoiceWeChat` | `DoubaoVoiceWeChat.dylib` + `.deb` ← 要这个 |
| `build-log` | 编译日志，出错时才看 |

下载 zip → 解压 → 拿 `.dylib`。

## 4. 注入微信

1. `.dylib` 传到手机（AirDrop / Filza / 微信文件传输）
2. 打开 **TrollFools**
3. 找到 **微信** → 点注入 → 选这个 dylib
4. 点「注入并重启微信」

## 5. 填 KEY

微信 → 任意聊天 → 点 ➕ → 面板最后一格「声」→ 设置页：

| 项 | 填什么 |
| --- | --- |
| API Key | 火山引擎控制台的 API Key |
| 资源 ID | `seed-tts-2.0`（2.0）或 `seed-icl-2.0`（1.0） |
| 音色 | 必须和资源 ID 同代 |

填完长按任意文字试。

## 6. 排错

```bash
idevicesyslog | grep "豆包语音"
```

启动应该看到：

```
[豆包语音] dylib 已注入 com.tencent.xin (pid=1234) longPress=1 streamPlay=1
[豆包语音] 已挂长按 → MMGrowTextView
```

| 现象 | 原因 |
| --- | --- |
| 一行日志都没有 | dylib 没注入，回 TrollFools 检查 |
| 只有第一行 | 没扫到文本视图，见下面的探测 |
| `code=45000001` | `X-Api-Resource-Id` 缺或错 |
| `code=55000000` | 音色和资源 ID 不同代 |
| `Invalid X-Api-Key` | KEY 不对 |
| 有提示但没声音 | 微信占着 audio session，杀掉微信重开 |

### 长按没反应时

把 `dv_is_readable_text_view` 里的 `f.size.height < 10` 改成 `< 6`，
并且在 `Tweak.xm` 的 `UILabel` hook 里临时加一句日志：

```objc
NSLog(@"[豆包语音] 扫到 %@ text=%@", NSStringFromClass([self class]), self.text);
```

看它到底扫到了哪些类。

---

## 7. 源码结构

```
TTS/
  DVProtocol.h/.m      二进制帧封包/解包（与安卓 TtsProtocol.kt 同逻辑，已字节级对拍）
  DVWebSocket.h/.m     NSURLSessionWebSocketTask 封装
  DVTTSEngine.h/.m     建连→StartSession→逐段TaskRequest→收PCM→FinishSession
  DVAudioPlayer.h/.m   AVAudioEngine + AVAudioPlayerNode 流式播 16bit PCM
  DVTextChunker.h/.m   90 字按句切段
UI/
  DVHUD.h/.m           浮窗提示
  DVMenuController.h/.m 长按弹出的 ActionSheet
  DVMoreInjector.h/.m  加号面板插入入口
Prefs/
  DVStore.h/.m         API Key 存 Keychain，配置存 NSUserDefaults
  DVSettingsController.h/.m  设置页
Tweak.xm               注入主体
```

## 8. 已知限制

| 功能 | 状态 |
| --- | --- |
| 长按朗读 | ✅ |
| 边合成边播 | ✅（可在设置页关） |
| 长文切段 | ✅ |
| 语速调节 | ❌ |
| 暂停/继续 | ❌ 只有停止 |
| 保存音频 | ❌ |

协议层沿用的是安卓版那份做过字节级对拍的实现；Objective-C 上层没在真机上跑过。
