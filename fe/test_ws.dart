import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

void main() {
  if (kDebugMode) {
    print(ws_status.normalClosure);
  }
}
