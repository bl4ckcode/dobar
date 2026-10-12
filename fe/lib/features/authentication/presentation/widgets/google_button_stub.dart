// Stub for non-web platforms
// This file is used on iOS/Android where renderButton doesn't exist

import 'package:flutter/widgets.dart';

/// Stub for the web-only renderButton method.
/// On mobile platforms, this should never be called since we use authenticate().
Widget renderButton() {
  throw StateError('renderButton should only be called on web');
}
