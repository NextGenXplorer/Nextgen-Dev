import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../infrastructure/keystore_service.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _keyController = TextEditingController();
  final _localUrlController = TextEditingController(
    text: 'http://10.0.2.2:11434/v1',
  );
  final _localModelController = TextEditingController(text: 'llama3');

  String _selectedProvider = 'gemini';
  bool _isLoading = false;
  bool _isObscured = true;

  final Map<String, String> _providerLabels = {
    'gemini': 'Google Gemini API Key',
    'openai': 'OpenAI API Key',
    'anthropic': 'Anthropic API Key',
    'groq': 'Groq API Key',
    'openrouter': 'OpenRouter API Key',
    'local': 'Local AI Endpoint',
  };

  final Map<String, String> _providerKeyNames = {
    'gemini': 'GEMINI_API_KEY',
    'openai': 'OPENAI_API_KEY',
    'anthropic': 'ANTHROPIC_API_KEY',
    'groq': 'GROQ_API_KEY',
    'openrouter': 'OPENROUTER_API_KEY',
    'local': 'LOCAL_AI_API_KEY',
  };

  Future<void> _completeOnboarding() async {
    final key = _keyController.text.trim();
    final keystore = ref.read(keystoreServiceProvider);

    setState(() {
      _isLoading = true;
    });

    // Store the selected provider
    await keystore.store('SELECTED_AI_PROVIDER', _selectedProvider);

    if (_selectedProvider == 'local') {
      await keystore.store(
        'LOCAL_AI_BASE_URL',
        _localUrlController.text.trim(),
      );
      await keystore.store('LOCAL_AI_MODEL', _localModelController.text.trim());
      if (key.isNotEmpty) {
        await keystore.store('LOCAL_AI_API_KEY', key);
      }
    } else {
      if (key.isNotEmpty) {
        await keystore.store(_providerKeyNames[_selectedProvider]!, key);
      }
    }

    if (mounted) {
      context.go('/home/chat');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLocal = _selectedProvider == 'local';

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.shield_outlined,
                size: 64,
                color: Colors.greenAccent,
              ),
              const SizedBox(height: 24),
              const Text(
                'Security First IDE',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                "Choose your AI engine. Selecting 'Local' ensures your code never leaves your network.",
                style: TextStyle(fontSize: 16, color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              DropdownButtonFormField<String>(
                value: _selectedProvider,
                decoration: const InputDecoration(
                  labelText: 'Primary Provider',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(
                    value: 'local',
                    child: Text('Local / On-Premise (Private)'),
                  ),
                  const DropdownMenuItem(
                    value: 'gemini',
                    child: Text('Google Gemini (Cloud)'),
                  ),
                  const DropdownMenuItem(
                    value: 'openai',
                    child: Text('OpenAI (Cloud)'),
                  ),
                  const DropdownMenuItem(
                    value: 'anthropic',
                    child: Text('Anthropic (Cloud)'),
                  ),
                  const DropdownMenuItem(
                    value: 'groq',
                    child: Text('Groq (Cloud)'),
                  ),
                  const DropdownMenuItem(
                    value: 'openrouter',
                    child: Text('OpenRouter (Cloud)'),
                  ),
                ],
                onChanged: (val) {
                  setState(() {
                    _selectedProvider = val!;
                  });
                },
              ),
              const SizedBox(height: 24),

              if (isLocal) ...[
                TextField(
                  controller: _localUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Endpoint URL',
                    hintText: 'http://10.0.2.2:11434/v1',
                    border: OutlineInputBorder(),
                    helperText: 'Use 10.0.2.2 for host machine from emulator',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _localModelController,
                  decoration: const InputDecoration(
                    labelText: 'Model Identifier',
                    hintText: 'llama3',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              TextField(
                controller: _keyController,
                obscureText: _isObscured,
                decoration: InputDecoration(
                  labelText: isLocal
                      ? 'API Key (Optional)'
                      : _providerLabels[_selectedProvider],
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.key),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isObscured ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _isObscured = !_isObscured;
                      });
                    },
                  ),
                ),
              ),

              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _completeOnboarding,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Start Private Session',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.go('/home/chat'),
                child: const Text('Skip setup (Work Offline)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
