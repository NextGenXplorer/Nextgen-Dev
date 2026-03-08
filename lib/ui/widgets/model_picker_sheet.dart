import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../infrastructure/keystore_service.dart';
import '../themes.dart';

// Model descriptor for the picker
class ModelDescriptor {
  final String id;
  final String name;
  final String tagline;
  final String keystoreKey;
  final IconData icon;
  final Color iconColor;

  const ModelDescriptor({
    required this.id,
    required this.name,
    required this.tagline,
    required this.keystoreKey,
    required this.icon,
    required this.iconColor,
  });
}

const allModels = [
  ModelDescriptor(
    id: 'gemini',
    name: 'Gemini',
    tagline: 'Google\'s multimodal AI',
    keystoreKey: 'GEMINI_API_KEY',
    icon: Icons.auto_awesome,
    iconColor: Color(0xFF4285F4),
  ),
  ModelDescriptor(
    id: 'openai',
    name: 'GPT-4o',
    tagline: 'OpenAI\'s flagship model',
    keystoreKey: 'OPENAI_API_KEY',
    icon: Icons.lens_blur,
    iconColor: Color(0xFF10A37F),
  ),
  ModelDescriptor(
    id: 'anthropic',
    name: 'Claude',
    tagline: 'Anthropic — safe & thoughtful',
    keystoreKey: 'ANTHROPIC_API_KEY',
    icon: Icons.all_inclusive,
    iconColor: Color(0xFFD97706),
  ),
  ModelDescriptor(
    id: 'groq',
    name: 'Groq',
    tagline: 'Ultra-fast inference',
    keystoreKey: 'GROQ_API_KEY',
    icon: Icons.bolt,
    iconColor: Color(0xFFF97316),
  ),
  ModelDescriptor(
    id: 'openrouter',
    name: 'OpenRouter',
    tagline: 'Access 100+ models',
    keystoreKey: 'OPENROUTER_API_KEY',
    icon: Icons.hub,
    iconColor: Color(0xFF8B5CF6),
  ),
  ModelDescriptor(
    id: 'local',
    name: 'Local / Ollama',
    tagline: 'On-device, 100% private',
    keystoreKey: 'LOCAL_AI_BASE_URL',
    icon: Icons.computer,
    iconColor: Color(0xFF22C55E),
  ),
];

class ModelPickerSheet extends ConsumerStatefulWidget {
  final String selectedModelId;
  final void Function(String modelId) onModelSelected;

  const ModelPickerSheet({
    super.key,
    required this.selectedModelId,
    required this.onModelSelected,
  });

  @override
  ConsumerState<ModelPickerSheet> createState() => _ModelPickerSheetState();
}

class _ModelPickerSheetState extends ConsumerState<ModelPickerSheet> {
  Map<String, bool> _keyStatus = {};

  @override
  void initState() {
    super.initState();
    _loadKeyStatuses();
  }

  Future<void> _loadKeyStatuses() async {
    final keystore = ref.read(keystoreServiceProvider);
    final statuses = <String, bool>{};
    for (final model in allModels) {
      final key = await keystore.retrieve(model.keystoreKey);
      statuses[model.id] = key != null && key.isNotEmpty;
    }
    if (mounted) setState(() => _keyStatus = statuses);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppThemes.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppThemes.textSecondary.withAlpha(80),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Text(
                  'Choose Model',
                  style: TextStyle(
                    color: AppThemes.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppThemes.dividerColor),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.65,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: allModels.length,
              separatorBuilder: (_, __) => const SizedBox(height: 0),
              itemBuilder: (context, i) => _buildModelTile(allModels[i]),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildModelTile(ModelDescriptor model) {
    final isSelected = model.id == widget.selectedModelId;
    final hasKey = _keyStatus[model.id] ?? false;

    return InkWell(
      onTap: () {
        if (hasKey) {
          widget.onModelSelected(model.id);
          Navigator.of(context).pop();
        } else {
          Navigator.of(context).pop();
          Navigator.of(context).pushNamed('/settings');
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: model.iconColor.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(model.icon, color: model.iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    model.name,
                    style: const TextStyle(
                      color: AppThemes.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    model.tagline,
                    style: const TextStyle(
                      color: AppThemes.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppThemes.accentBlue, size: 20)
            else if (!hasKey)
              GestureDetector(
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushNamed('/settings');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppThemes.dividerColor),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Add Key',
                    style: TextStyle(
                      color: AppThemes.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              )
            else
              GestureDetector(
                onTap: () {
                  widget.onModelSelected(model.id);
                  Navigator.of(context).pop();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppThemes.dividerColor),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Select',
                    style: TextStyle(color: AppThemes.textSecondary, fontSize: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Helper to show the model picker bottom sheet
Future<void> showModelPicker(
  BuildContext context, {
  required String currentModel,
  required ValueChanged<String> onModelSelected,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => ModelPickerSheet(
      selectedModelId: currentModel,
      onModelSelected: onModelSelected,
    ),
  );
}
