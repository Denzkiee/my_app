import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  SecureStorageService._();

  static final SecureStorageService instance = SecureStorageService._();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const _userIdKey = 'dental_booking_user_id';

  Future<void> saveUserId(int id) async {
    await _storage.write(key: _userIdKey, value: id.toString());
  }

  Future<int?> getUserId() async {
    final value = await _storage.read(key: _userIdKey);
    return value == null ? null : int.tryParse(value);
  }

  Future<void> clearUserId() async {
    await _storage.delete(key: _userIdKey);
  }
}
