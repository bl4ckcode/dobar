/// Platform detection helpers for native (io) platforms

import 'dart:io' show Platform;

bool isAndroidPlatform() => Platform.isAndroid;
bool isIOSPlatform() => Platform.isIOS;
