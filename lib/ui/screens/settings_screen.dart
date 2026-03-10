import 'dart:ui';
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

  // Model selection
  String _geminiModel = 'gemini-2.5-flash';
  String _openaiModel = 'gpt-4o-mini';
  String _anthropicModel = 'claude-3-5-haiku-20241022';
  String _groqModel = 'llama3-70b-8192';
  final _openrouterModelCtrl = TextEditingController();

  String _activeProvider = 'gemini';
  bool _isLoading = true;
  final Map<String, bool> _obscured = {};
  final Map<String, bool> _savingMap = {};

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final keystore = ref.read(keystoreServiceProvider);

    _activeProvider = await keystore.retrieve('SELECTED_AI_PROVIDER') ?? 'gemini';
    _userNameCtrl.text = await keystore.retrieve('USER_NAME') ?? '';

    // Cloud API keys (load actual keys! obscureText handles hiding them securely in the UI)
    _geminiCtrl.text = await keystore.retrieve('GEMINI_API_KEY') ?? '';
    _openaiCtrl.text = await keystore.retrieve('OPENAI_API_KEY') ?? '';
    _anthropicCtrl.text = await keystore.retrieve('ANTHROPIC_API_KEY') ?? '';
    _groqCtrl.text = await keystore.retrieve('GROQ_API_KEY') ?? '';
    _openrouterCtrl.text = await keystore.retrieve('OPENROUTER_API_KEY') ?? '';

    // Models
    _geminiModel = await keystore.retrieve('GEMINI_MODEL') ?? 'gemini-2.5-flash';
    _openaiModel = await keystore.retrieve('OPENAI_MODEL') ?? 'gpt-4o-mini';
    _anthropicModel = await keystore.retrieve('ANTHROPIC_MODEL') ?? 'claude-3-5-haiku-20241022';
    _groqModel = await keystore.retrieve('GROQ_MODEL') ?? 'llama3-70b-8192';
    _openrouterModelCtrl.text = await keystore.retrieve('OPENROUTER_MODEL') ?? 'openai/gpt-4o-mini';

    // Local AI
    _localUrlCtrl.text =
        await keystore.retrieve('LOCAL_AI_BASE_URL') ?? 'http://10.0.2.2:11434/v1';
    _localModelCtrl.text = await keystore.retrieve('LOCAL_AI_MODEL') ?? 'llama3';
    _localKeyCtrl.text = await keystore.retrieve('LOCAL_AI_API_KEY') ?? '';

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _saveKey(String keystoreKey, String value, String providerId) async {
    // Save exactly what is in the field
    if (value.isEmpty) return;
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
    _openrouterModelCtrl.dispose();
    _localUrlCtrl.dispose();
    _localModelCtrl.dispose();
    _localKeyCtrl.dispose();
    _userNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: AppThemes.bgDark.withAlpha(150),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withAlpha(10),
                    width: 0.5,
                  ),
                ),
              ),
              child: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                centerTitle: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppThemes.textPrimary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                title: const Text(
                  'Settings',
                  style: TextStyle(
                    color: AppThemes.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.8, -0.6),
            radius: 1.5,
            colors: [
              Color(0xFF1A1628), // Deep purple mesh top right
              Color(0xFF0A0A0C),
              Color(0xFF0A0A0C),
            ],
            stops: [0.0, 0.4, 1.0],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppThemes.accentBlue))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, kToolbarHeight + 32, 16, 32),
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
                  _buildModelDropdown(
                    value: _geminiModel,
                    options: const ['gemini-2.5-flash', 'gemini-2.5-pro', 'gemini-1.5-pro', 'gemini-1.5-flash'],
                    keystoreKey: 'GEMINI_MODEL',
                    onChanged: (val) => setState(() => _geminiModel = val),
                  ),
                  _divider(),
                  _buildKeyRow(
                    model: allModels[1], // OpenAI
                    ctrl: _openaiCtrl,
                    keystoreKey: 'OPENAI_API_KEY',
                  ),
                  _buildModelDropdown(
                    value: _openaiModel,
                    options: const ['gpt-4o', 'gpt-4o-mini', 'o1', 'o1-mini'],
                    keystoreKey: 'OPENAI_MODEL',
                    onChanged: (val) => setState(() => _openaiModel = val),
                  ),
                  _divider(),
                  _buildKeyRow(
                    model: allModels[2], // Anthropic
                    ctrl: _anthropicCtrl,
                    keystoreKey: 'ANTHROPIC_API_KEY',
                  ),
                  _buildModelDropdown(
                    value: _anthropicModel,
                    options: const ['claude-3-5-sonnet-20241022', 'claude-3-5-haiku-20241022', 'claude-3-opus-20240229'],
                    keystoreKey: 'ANTHROPIC_MODEL',
                    onChanged: (val) => setState(() => _anthropicModel = val),
                  ),
                  _divider(),
                  _buildKeyRow(
                    model: allModels[3], // Groq
                    ctrl: _groqCtrl,
                    keystoreKey: 'GROQ_API_KEY',
                  ),
                  _buildModelDropdown(
                    value: _groqModel,
                    options: const ['llama3-70b-8192', 'llama3-8b-8192', 'mixtral-8x7b-32768', 'gemma2-9b-it'],
                    keystoreKey: 'GROQ_MODEL',
                    onChanged: (val) => setState(() => _groqModel = val),
                  ),
                  _divider(),
                  _buildKeyRow(
                    model: allModels[4], // OpenRouter
                    ctrl: _openrouterCtrl,
                    keystoreKey: 'OPENROUTER_API_KEY',
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 32, right: 0, bottom: 8),
                    child: _buildTextField(
                      ctrl: _openrouterModelCtrl,
                      label: 'Model ID (e.g. openai/gpt-4o)',
                      icon: Icons.auto_awesome,
                      onSave: () async {
                        final ks = ref.read(keystoreServiceProvider);
                        final messenger = ScaffoldMessenger.of(context);
                        await ks.store('OPENROUTER_MODEL', _openrouterModelCtrl.text.trim());
                        ref.invalidate(aiProviderServiceProvider);
                        if (mounted) {
                          messenger.showSnackBar(
                            const SnackBar(content: Text('OpenRouter Model saved ✅')),
                          );
                        }
                      },
                    ),
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
            ),
    );
  }

  Widget _sectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: AppThemes.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161618).withAlpha(180),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withAlpha(10), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(40),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  Widget _divider() {
    return Divider(
      height: 1,
      indent: 52,
      color: Colors.white.withAlpha(5),
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
                  decoration: InputDecoration(
                    hintText: hint ?? 'Paste API key...',
                    hintStyle: const TextStyle(
                      color: AppThemes.textSecondary,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: Colors.black.withAlpha(80),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                    suffixIcon: IconButton(
                      icon: Icon(
                        isObscured ? Icons.visibility_off_rounded : Icons.visibility_rounded,
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
                    color: AppThemes.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: ctrl,
                  style: const TextStyle(color: AppThemes.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Enter $label...',
                    hintStyle: const TextStyle(color: AppThemes.textSecondary, fontSize: 13),
                    filled: true,
                    fillColor: Colors.black.withAlpha(80),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
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

  Widget _buildModelDropdown({
    required String value,
    required List<String> options,
    required String keystoreKey,
    required ValueChanged<String> onChanged,
  }) {
    // Ensure the current value is in the options list
    final List<String> finalOptions = [...options];
    if (!finalOptions.contains(value)) {
      finalOptions.add(value);
    }

    return Padding(
      padding: const EdgeInsets.only(left: 48, right: 16, bottom: 12),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(80),
          borderRadius: BorderRadius.circular(10),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            dropdownColor: AppThemes.surfaceDark,
            icon: const Icon(Icons.arrow_drop_down, color: AppThemes.textSecondary),
            style: const TextStyle(color: AppThemes.textPrimary, fontSize: 13),
            onChanged: (String? newValue) async {
              if (newValue != null && newValue != value) {
                final ks = ref.read(keystoreServiceProvider);
                await ks.store(keystoreKey, newValue);
                ref.invalidate(aiProviderServiceProvider);
                onChanged(newValue);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Model updated ✅'), backgroundColor: AppThemes.surfaceCard,),
                  );
                }
              }
            },
            items: finalOptions.map<DropdownMenuItem<String>>((String modelStr) {
              return DropdownMenuItem<String>(
                value: modelStr,
                child: Text(modelStr),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

