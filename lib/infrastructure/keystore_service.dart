import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final keystoreServiceProvider = Provider<KeystoreService>((ref) {
  return KeystoreService(const FlutterSecureStorage());
});

class KeystoreService {
  final FlutterSecureStorage _storage;

  KeystoreService(this._storage);

  /// Stores an API key for a specific AI provider.
  Future<void> store(String provider, String key) async {
    await _storage.write(key: 'provider_$provider', value: key);
  }

  /// Retrieves an API key for a specific AI provider.
  Future<String?> retrieve(String provider) async {
    return await _storage.read(key: 'provider_$provider');
  }

  /// Deletes an API key for a specific AI provider.
  Future<void> delete(String provider) async {
    await _storage.delete(key: 'provider_$provider');
  }

  /// Lists all stored AI provider names.
  Future<List<String>> listProviders() async {
    final all = await _storage.readAll();
    return all.keys
        .where((k) => k.startsWith('provider_'))
        .map((k) => k.replaceFirst('provider_', ''))
        .toList();
  }

  /// Masks a key to string showing only last 4 chars
  static String maskKey(String key) {
    if (key.length <= 4) return '*' * key.length;
    return '${'*' * (key.length - 4)}${key.substring(key.length - 4)}';
  }
}
