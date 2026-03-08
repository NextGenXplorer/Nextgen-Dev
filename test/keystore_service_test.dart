import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile_ai_ide/infrastructure/keystore_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('KeystoreService', () {
    late KeystoreService service;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      service = KeystoreService(const FlutterSecureStorage());
    });

    test('stores and retrieves a key', () async {
      await service.store('openai', 'sk-12345678');
      final key = await service.retrieve('openai');
      expect(key, 'sk-12345678');
    });

    test('deletes a key', () async {
      await service.store('claude', 'sk-ant-123');
      await service.delete('claude');
      final key = await service.retrieve('claude');
      expect(key, isNull);
    });

    test('lists providers', () async {
      await service.store('openai', '123');
      await service.store('groq', '456');
      final providers = await service.listProviders();
      expect(providers, containsAll(['openai', 'groq']));
      expect(providers.length, 2);
    });

    test('masks key', () {
      expect(KeystoreService.maskKey('sk-12345678'), '*******5678');
      expect(KeystoreService.maskKey('key'), '***');
    });
  });
}
