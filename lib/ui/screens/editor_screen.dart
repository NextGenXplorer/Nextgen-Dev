import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/agent_event.dart';
import '../../application/agent_bus.dart';
import '../widgets/code_editor_widget.dart';
import '../widgets/terminal_widget.dart';
import '../widgets/file_manager_drawer.dart';
import '../themes.dart';

class EditorScreen extends ConsumerWidget {
  final String projectId;
  final String filePath;

  const EditorScreen({
    super.key,
    required this.projectId,
    required this.filePath,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppThemes.bgDark,
      appBar: AppBar(
        title: Text(
          filePath.split('/').last,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppThemes.textPrimary,
          ),
        ),
        backgroundColor: AppThemes.surfaceDark,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppThemes.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: AppThemes.accentCyan),
            tooltip: 'AI Quick Fix',
            onPressed: () {
              _showAiPromptDialog(context, ref);
            },
          ),
          IconButton(
            icon: const Icon(Icons.play_arrow, color: Colors.green),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.save, color: AppThemes.textSecondary),
            onPressed: () {},
          ),
        ],
      ),
      drawer: const FileManagerDrawer(),
      body: Column(
        children: [
          // Main Editor Space
          Expanded(flex: 3, child: CodeEditorWidget(filePath: filePath)),
          // Resizer handle
          Container(height: 1, color: AppThemes.dividerColor),
          // Integrated Terminal Space
          const Expanded(flex: 2, child: TerminalWidget()),
        ],
      ),
    );
  }

  void _showAiPromptDialog(BuildContext context, WidgetRef ref) {
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppThemes.surfaceDark,
          title: const Text(
            'AI Quick Mod',
            style: TextStyle(color: AppThemes.textPrimary),
          ),
          content: TextField(
            controller: textController,
            style: const TextStyle(color: AppThemes.textPrimary),
            decoration: InputDecoration(
              hintText: 'e.g. Wrap this widget in a Column',
              hintStyle: const TextStyle(color: AppThemes.textSecondary),
              enabledBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: AppThemes.dividerColor),
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: AppThemes.accentCyan),
              ),
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppThemes.textSecondary),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppThemes.accentCyan,
              ),
              onPressed: () {
                final prompt = textController.text.trim();
                if (prompt.isNotEmpty) {
                  final bus = ref.read(agentBusProvider);
                  // Dispatch context-aware command directly to CoderAgent
                  bus.publish(
                    AgentEvent(
                      sourceAgent: 'User (Editor)',
                      targetAgent: 'CoderAgent',
                      type: AgentEventType.taskAssigned,
                      payload:
                          'Focus on file: $filePath\\nUser Request: $prompt\\nUse the read_file tool to see the code, and edit_file to apply the change.',
                    ),
                  );
                }
                Navigator.pop(ctx);
              },
              child: const Text('Execute'),
            ),
          ],
        );
      },
    );
  }
}
