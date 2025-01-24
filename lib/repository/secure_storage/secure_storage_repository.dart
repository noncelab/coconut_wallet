import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageRepository {
  SecureStorageRepository._internal();

  static final SecureStorageRepository _instance =
      SecureStorageRepository._internal();
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  factory SecureStorageRepository() {
    return _instance;
  }

  Future<void> write({required String key, required String value}) async {
    await _storage.write(key: key, value: value);
  }

  Future<String?> read({required String key}) async {
    return await _storage.read(key: key);
  }

  Future<void> delete({required String key}) async {
    await _storage.delete(key: key);
  }

  Future<List<String>> getAllKeys() async {
    final Map<String, String> allValues = await _storage.readAll();
    return allValues.keys.toList();
  }

  Future<void> deleteAll() async {
    await _storage.deleteAll();
  }
}
