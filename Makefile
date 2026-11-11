export TARGET = iphone:clang:latest:15.0
export ARCHS = arm64
export THEOS_PACKAGE_SCHEME = rootless
export TARGET_IPHONEOS_DEPLOYMENT_VERSION = 15.0

TWEAK_NAME = DoubaoVoiceWeChat
DoubaoVoiceWeChat_FILES = Tweak.xm Prefs/DVStore.m TTS/DVProtocol.m TTS/DVTextChunker.m UI/DVHUD.m TTS/DVWebSocket.m TTS/DVAudioPlayer.m TTS/DVTTSEngine.m
DoubaoVoiceWeChat_FRAMEWORKS = UIKit Foundation AVFoundation CoreGraphics QuartzCore Security
DoubaoVoiceWeChat_CFLAGS = -I$(THEOS_PROJECT_DIR) -fobjc-arc -Wno-deprecated-declarations -Wno-unused-variable
DoubaoVoiceWeChat_LDFLAGS = -undefined dynamic_lookup

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 WeChat"
