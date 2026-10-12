/// Platform detection helpers for native (io) platforms
library;

import 'dart:io' show Platform;

bool isAndroidPlatform() => Platform.isAndroid;
bool isIOSPlatform() => Platform.isIOS;
