import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:mobile_ai_ide/infrastructure/ai_providers/local_ai_provider.dart';
import 'package:mobile_ai_ide/domain/models/chat_message.dart';

import 'ai_providers_test.mocks.dart';

@GenerateMocks([http.Client])
void main() {
  late MockClient mockClient;
  late LocalAIProvider localProvider;

  setUp(() {
    mockClient = MockClient();
    localProvider = LocalAIProvider(
      baseUrl: 'http://localhost:11434/v1',
      model: 'llama3',
      apiKey: 'test-key',
      client: mockClient,
    );
  });

  group('LocalAIProvider', () {
    test('generate returns content on success', () async {
      final responseBody = jsonEncode({
        'choices': [
          {
            'message': {'content': 'Hello from local AI!'},
          },
        ],
      });

      when(
        mockClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => http.Response(responseBody, 200));

      final result = await localProvider.generate([
        const ChatMessage(role: MessageRole.user, content: 'Hi'),
      ]);

      expect(result, 'Hello from local AI!');

      // Verify parameters
      final verification = verify(
        mockClient.post(
          argThat(
            predicate(
              (Uri uri) =>
                  uri.toString() ==
                  'http://localhost:11434/v1/chat/completions',
            ),
          ),
          headers: captureAnyNamed('headers'),
          body: captureAnyNamed('body'),
        ),
      );

      final headers = verification.captured[0] as Map<String, String>;
      final body = jsonDecode(verification.captured[1] as String);

      expect(headers['Authorization'], 'Bearer test-key');
      expect(body['model'], 'llama3');
      expect(body['messages'][0]['content'], 'Hi');
    });

    test('generate throws exception on error', () async {
      when(
        mockClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => http.Response('Error message', 500));

      expect(
        () => localProvider.generate([
          const ChatMessage(role: MessageRole.user, content: 'Hi'),
        ]),
        throwsException,
      );
    });
  });
}
