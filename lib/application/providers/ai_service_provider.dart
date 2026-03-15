import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/interfaces/ai_provider.dart';
import '../../infrastructure/ai_providers/google_gemini_provider.dart';
import '../../infrastructure/ai_providers/openai_provider.dart';
import '../../infrastructure/ai_providers/anthropic_provider.dart';
import '../../infrastructure/ai_providers/groq_provider.dart';
import '../../infrastructure/ai_providers/openrouter_provider.dart';
import '../../infrastructure/ai_providers/local_ai_provider.dart';
import '../../infrastructure/keystore_service.dart';

// Provider for the currently active AI provider
final aiProviderServiceProvider = FutureProvider<AIProvider?>((ref) async {
  final keystore = ref.watch(keystoreServiceProvider);

  // See which provider the user wants to use
  // (defaults to 'gemini' if not set, handled below)
  final selectedProvider =
      await keystore.retrieve('SELECTED_AI_PROVIDER') ?? 'gemini';

  switch (selectedProvider) {
    case 'openai':
      final key = await keystore.retrieve('OPENAI_API_KEY');
      final model = await keystore.retrieve('OPENAI_MODEL') ?? 'gpt-4o-mini';
      if (key != null && key.isNotEmpty)
        return OpenAIProvider(apiKey: key, model: model);
      break;
    case 'anthropic':
      final key = await keystore.retrieve('ANTHROPIC_API_KEY');
      final model =
          await keystore.retrieve('ANTHROPIC_MODEL') ??
          'claude-3-5-haiku-20241022';
      if (key != null && key.isNotEmpty)
        return AnthropicProvider(apiKey: key, model: model);
      break;
    case 'groq':
      final key = await keystore.retrieve('GROQ_API_KEY');
      final model = await keystore.retrieve('GROQ_MODEL') ?? 'llama3-70b-8192';
      if (key != null && key.isNotEmpty)
        return GroqProvider(apiKey: key, model: model);
      break;
    case 'openrouter':
      final key = await keystore.retrieve('OPENROUTER_API_KEY');
      final model =
          await keystore.retrieve('OPENROUTER_MODEL') ?? 'openai/gpt-4o-mini';
      if (key != null && key.isNotEmpty)
        return OpenRouterProvider(apiKey: key, model: model);
      break;
    case 'local':
      final baseUrl =
          await keystore.retrieve('LOCAL_AI_BASE_URL') ??
          'http://10.0.2.2:11434/v1'; // Default to host machine from emulator
      final model = await keystore.retrieve('LOCAL_AI_MODEL') ?? 'llama3';
      final apiKey = await keystore.retrieve('LOCAL_AI_API_KEY');
      return LocalAIProvider(baseUrl: baseUrl, model: model, apiKey: apiKey);
    case 'gemini':
    default:
      final key = await keystore.retrieve('GEMINI_API_KEY');
      final modelName =
          await keystore.retrieve('GEMINI_MODEL') ?? 'gemini-2.5-flash';
      if (key != null && key.isNotEmpty)
        return GoogleGeminiProvider(apiKey: key, modelName: modelName);
      break;
  }

  return null; // No matching configured provider found
});
