import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _storage = FlutterSecureStorage();
Future<String?> readInvitation() =>
    _storage.read(key: 'pending_staff_invitation');
Future<void> writeInvitation(String? code) => code == null
    ? _storage.delete(key: 'pending_staff_invitation')
    : _storage.write(key: 'pending_staff_invitation', value: code);
