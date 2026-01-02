import 'package:permission_handler/permission_handler.dart' as perm;

Future<bool> requestLocationPermission() async {
  perm.PermissionStatus status = await perm.Permission.location.request();

  if (status.isDenied) {
    // Permission is denied, show a dialog or message to inform the user
    // Optionally, open app settings to allow the user to enable the permission
    perm.openAppSettings();
    return false;
  }

  return status.isGranted;
}
