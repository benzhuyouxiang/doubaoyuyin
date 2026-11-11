export TARGET = iphone:clang:latest:15.0
export ARCHS = arm64
export THEOS_PACKAGE_SCHEME = rootless
export TARGET_IPHONEOS_DEPLOYMENT_VERSION = 15.0
export ADDITIONAL_CFLAGS = -fobjc-arc

TWEAK_NAME = DoubaoVoiceWeChat
DoubaoVoiceWeChat_FILES = Tweak.xm \
    TTS/DVProtocol.m TTS/DVWebSocket.m TTS/DVTTSEngine.m \
    TTS/DVAudioPlayer.m TTS/DVTextChunker.m \
    UI/DVHUD.m UI/DVMenuController.m UI/DVMoreInjector.m \
    Prefs/DVStore.m Prefs/DVSettingsController.m
DoubaoVoiceWeChat_FRAMEWORKS = UIKit Foundation AVFoundation CoreGraphics QuartzCore Security
DoubaoVoiceWeChat_CFLAGS = -I$(THEOS_PROJECT_DIR) -fobjc-arc -Wno-deprecated-declarations -Wno-unused-variable
DoubaoVoiceWeChat_LDFLAGS = -undefined dynamic_lookup

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 WeChat"
