import 'package:web/web.dart' as web;

Future<String?> readInvitation() async =>
    web.window.sessionStorage.getItem('pending_staff_invitation');
Future<void> writeInvitation(String? code) async {
  if (code == null) {
    web.window.sessionStorage.removeItem('pending_staff_invitation');
  } else {
    web.window.sessionStorage.setItem('pending_staff_invitation', code);
  }
}
