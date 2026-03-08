import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../infrastructure/keystore_service.dart';
import '../../application/providers/ai_service_provider.dart';
import '../themes.dart';
import '../widgets/model_picker_sheet.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Cloud provider controllers
  final _geminiCtrl = TextEditingController();
  final _openaiCtrl = TextEditingController();
  final _anthropicCtrl = TextEditingController();
  final _groqCtrl = TextEditingController();
  final _openrouterCtrl = TextEditingController();

  // Local AI controllers
  final _localUrlCtrl = TextEditingController();
  final _localModelCtrl = TextEditingController();
  final _localKeyCtrl = TextEditingController();

  // User info
  final _userNameCtrl = TextEditingController();

  String _activeProvider = 'gemini';
  bool _isLoading = true;
  final Map<String, bool> _obscured = {};
  final Map<String, bool> _savingMap = {};
  // Track which fields have been edited by the user (vs showing masked placeholder)
  final Map<String, bool> _isDirty = {};

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final keystore = ref.read(keystoreServiceProvider);

    _activeProvider = await keystore.retrieve('SELECTED_AI_PROVIDER') ?? 'gemini';
    _userNameCtrl.text = await keystore.retrieve('USER_NAME') ?? '';

    // Cloud API keys (masked)
    _geminiCtrl.text = await _maskedOr(keystore, 'GEMINI_API_KEY');
    _openaiCtrl.text = await _maskedOr(keystore, 'OPENAI_API_KEY');
    _anthropicCtrl.text = await _maskedOr(keystore, 'ANTHROPIC_API_KEY');
    _groqCtrl.text = await _maskedOr(keystore, 'GROQ_API_KEY');
    _openrouterCtrl.text = await _maskedOr(keystore, 'OPENROUTER_API_KEY');

    // Local AI
    _localUrlCtrl.text =
        await keystore.retrieve('LOCAL_AI_BASE_URL') ?? 'http://10.0.2.2:11434/v1';
    _localModelCtrl.text = await keystore.retrieve('LOCAL_AI_MODEL') ?? 'llama3';
    _localKeyCtrl.text = await _maskedOr(keystore, 'LOCAL_AI_API_KEY');

    if (mounted) setState(() => _isLoading = false);
  }

  Future<String> _maskedOr(KeystoreService ks, String key) async {
    final val = await ks.retrieve(key);
    if (val == null || val.isEmpty) return '';
    return KeystoreService.maskKey(val);
  }

  Future<void> _saveKey(String keystoreKey, String value, String providerId) async {
    // Only save if the user has actually typed something new (not just the masked placeholder)
    if (value.isEmpty) return;
    if (value.contains('*') && !(_isDirty[keystoreKey] ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tap the field and paste your new key first'),
          backgroundColor: Color(0xFF7A1515),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    setState(() => _savingMap[providerId] = true);
    final keystore = ref.read(keystoreServiceProvider);
    await keystore.store(keystoreKey, value);
    ref.invalidate(aiProviderServiceProvider);
    if (mounted) {
      setState(() => _savingMap[providerId] = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_labelFor(keystoreKey)} saved ✅'),
          backgroundColor: AppThemes.surfaceCard,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _setActiveProvider(String id) async {
    final keystore = ref.read(keystoreServiceProvider);
    await keystore.store('SELECTED_AI_PROVIDER', id);
    ref.invalidate(aiProviderServiceProvider);
    setState(() => _activeProvider = id);
  }

  String _labelFor(String key) {
    switch (key) {
      case 'GEMINI_API_KEY':
        return 'Gemini Key';
      case 'OPENAI_API_KEY':
        return 'OpenAI Key';
      case 'ANTHROPIC_API_KEY':
        return 'Anthropic Key';
      case 'GROQ_API_KEY':
        return 'Groq Key';
      case 'OPENROUTER_API_KEY':
        return 'OpenRouter Key';
      default:
        return 'Key';
    }
  }

  @override
  void dispose() {
    _geminiCtrl.dispose();
    _openaiCtrl.dispose();
    _anthropicCtrl.dispose();
    _groqCtrl.dispose();
    _openrouterCtrl.dispose();
    _localUrlCtrl.dispose();
    _localModelCtrl.dispose();
    _localKeyCtrl.dispose();
    _userNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemes.bgDark,
      appBar: AppBar(
        backgroundColor: AppThemes.bgDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppThemes.accentBlue))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Profile Section
                _sectionHeader('Profile'),
                _buildCard([
                  _buildTextField(
                    ctrl: _userNameCtrl,
                    label: 'Your Name',
                    icon: Icons.person_outline,
                    onSave: () async {
                      final ks = ref.read(keystoreServiceProvider);
                      final messenger = ScaffoldMessenger.of(context);
                      await ks.store('USER_NAME', _userNameCtrl.text.trim());
                      if (mounted) {
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Name saved ✅')),
                        );
                      }
                    },
                  ),
                ]),
                const SizedBox(height: 24),

                // Active Model Section
                _sectionHeader('Active AI Model'),
                _buildCard([
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppThemes.accentBlue.withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        allModels.firstWhere((m) => m.id == _activeProvider).icon,
                        color: AppThemes.accentBlue,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      allModels.firstWhere((m) => m.id == _activeProvider).name,
                      style: const TextStyle(
                        color: AppThemes.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(
                      'Tap to change',
                      style: TextStyle(color: AppThemes.textSecondary, fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: AppThemes.textSecondary),
                    onTap: () => showModelPicker(
                      context,
                      currentModel: _activeProvider,
                      onModelSelected: _setActiveProvider,
                    ),
                  ),
                ]),
                const SizedBox(height: 24),

                // API Keys Section
                _sectionHeader('API Keys'),
                _buildCard([
                  _buildKeyRow(
                    model: allModels[0], // Gemini
                    ctrl: _geminiCtrl,
                    keystoreKey: 'GEMINI_API_KEY',
                  ),
                  _divider(),
                  _buildKeyRow(
                    model: allModels[1], // OpenAI
                    ctrl: _openaiCtrl,
                    keystoreKey: 'OPENAI_API_KEY',
                  ),
                  _divider(),
                  _buildKeyRow(
                    model: allModels[2], // Anthropic
                    ctrl: _anthropicCtrl,
                    keystoreKey: 'ANTHROPIC_API_KEY',
                  ),
                  _divider(),
                  _buildKeyRow(
                    model: allModels[3], // Groq
                    ctrl: _groqCtrl,
                    keystoreKey: 'GROQ_API_KEY',
                  ),
                  _divider(),
                  _buildKeyRow(
                    model: allModels[4], // OpenRouter
                    ctrl: _openrouterCtrl,
                    keystoreKey: 'OPENROUTER_API_KEY',
                  ),
                ]),
                const SizedBox(height: 24),

                // Local AI Section
                _sectionHeader('Local AI (Ollama / LM Studio)'),
                _buildCard([
                  _buildTextField(
                    ctrl: _localUrlCtrl,
                    label: 'Endpoint URL',
                    icon: Icons.link_outlined,
                    onSave: () async {
                      final ks = ref.read(keystoreServiceProvider);
                      final messenger = ScaffoldMessenger.of(context);
                      await ks.store('LOCAL_AI_BASE_URL', _localUrlCtrl.text.trim());
                      ref.invalidate(aiProviderServiceProvider);
                      if (mounted) {
                        messenger.showSnackBar(
                          const SnackBar(content: Text('URL saved ✅')),
                        );
                      }
                    },
                  ),
                  _divider(),
                  _buildTextField(
                    ctrl: _localModelCtrl,
                    label: 'Model Name (e.g. llama3)',
                    icon: Icons.memory_outlined,
                    onSave: () async {
                      final ks = ref.read(keystoreServiceProvider);
                      final messenger = ScaffoldMessenger.of(context);
                      await ks.store('LOCAL_AI_MODEL', _localModelCtrl.text.trim());
                      ref.invalidate(aiProviderServiceProvider);
                      if (mounted) {
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Model saved ✅')),
                        );
                      }
                    },
                  ),
                  _divider(),
                  _buildKeyRow(
                    model: allModels[5], // Local
                    ctrl: _localKeyCtrl,
                    keystoreKey: 'LOCAL_AI_API_KEY',
                    hint: 'API key (optional)',
                  ),
                ]),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _sectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: AppThemes.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppThemes.surfaceCard,
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  Widget _divider() {
    return const Divider(
      height: 1,
      indent: 56,
      color: AppThemes.dividerColor,
    );
  }

  Widget _buildKeyRow({
    required ModelDescriptor model,
    required TextEditingController ctrl,
    required String keystoreKey,
    String? hint,
  }) {
    final isObscured = _obscured[keystoreKey] ?? true;
    final isSaving = _savingMap[model.id] ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(model.icon, color: model.iconColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  model.name,
                  style: const TextStyle(
                    color: AppThemes.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: ctrl,
                  obscureText: isObscured,
                  style: const TextStyle(
                    color: AppThemes.textPrimary,
                    fontSize: 13,
                    fontFamily: 'monospace',
                  ),
                  // Clear masked placeholder when user taps so they can paste fresh
                  onTap: () {
                    if (ctrl.text.contains('*')) {
                      ctrl.clear();
                      setState(() => _isDirty[keystoreKey] = true);
                    }
                  },
                  // Mark as dirty whenever user types
                  onChanged: (_) => setState(() => _isDirty[keystoreKey] = true),
                  decoration: InputDecoration(
                    hintText: hint ?? 'Paste API key...',
                    hintStyle: const TextStyle(
                      color: AppThemes.textSecondary,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: AppThemes.bgDark,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                    suffixIcon: IconButton(
                      icon: Icon(
                        isObscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 16,
                        color: AppThemes.textSecondary,
                      ),
                      onPressed: () =>
                          setState(() => _obscured[keystoreKey] = !isObscured),
                    ),
                  ),
                  onSubmitted: (_) => _saveKey(keystoreKey, ctrl.text, model.id),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: isSaving ? null : () => _saveKey(keystoreKey, ctrl.text, model.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppThemes.accentBlue.withAlpha(isSaving ? 60 : 25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: isSaving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppThemes.accentBlue,
                      ),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(
                        color: AppThemes.accentBlue,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController ctrl,
    required String label,
    required IconData icon,
    required VoidCallback onSave,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: AppThemes.textSecondary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppThemes.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: ctrl,
                  style: const TextStyle(color: AppThemes.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppThemes.bgDark,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                  onSubmitted: (_) => onSave(),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onSave,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppThemes.accentBlue.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Save',
                style: TextStyle(
                  color: AppThemes.accentBlue,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
