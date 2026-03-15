import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../domain/models/agent_step.dart';
import '../themes.dart';

// ── Colour / icon configuration by tool name ──────────────────────────────────

class _ToolConfig {
  final IconData icon;
  final Color color;
  final String callLabel;
  const _ToolConfig(this.icon, this.color, this.callLabel);
}

const _toolConfigs = <String, _ToolConfig>{
  'create_file': _ToolConfig(
    Icons.note_add,
    AppThemes.accentCyan,
    '📄  CREATING FILE',
  ),
  'edit_file': _ToolConfig(
    Icons.edit_document,
    AppThemes.accentGold,
    '✏️  EDITING FILE',
  ),
  'read_file': _ToolConfig(
    Icons.description_outlined,
    AppThemes.accentCobalt,
    '📖  READING FILE',
  ),
  'list_directory': _ToolConfig(
    Icons.folder_open,
    AppThemes.accentCyan,
    '📁  LISTING DIR',
  ),
  'build_project': _ToolConfig(
    Icons.build_circle_outlined,
    AppThemes.accentGreen,
    '🏗️  BUILDING PROJECT',
  ),
  'run_terminal_command': _ToolConfig(
    Icons.terminal,
    AppThemes.accentGold,
    '⚡  RUNNING COMMAND',
  ),
  'install_package': _ToolConfig(
    Icons.download_for_offline,
    AppThemes.accentCobalt,
    '📦  INSTALLING PACKAGE',
  ),
  'git': _ToolConfig(Icons.merge_type, AppThemes.accentCyan, '🔀  GIT'),
  'web_search': _ToolConfig(
    Icons.search,
    AppThemes.textPrimary,
    '🔍  SEARCHING THE WEB',
  ),
  'read_url': _ToolConfig(
    Icons.link,
    AppThemes.accentCobalt,
    '🌐  READING PAGE',
  ),
  'take_screenshot': _ToolConfig(
    Icons.screenshot_monitor,
    AppThemes.accentGreen,
    '📸  SCREENSHOT',
  ),
  'dart_analyzer': _ToolConfig(
    Icons.analytics,
    AppThemes.accentGold,
    '🔬  ANALYZING CODE',
  ),
  'list_projects': _ToolConfig(
    Icons.folder_special,
    AppThemes.accentCyan,
    '📂  LISTING PROJECTS',
  ),
  'get_project_context': _ToolConfig(
    Icons.schema_outlined,
    AppThemes.accentCobalt,
    '🗂️  LOADING CONTEXT',
  ),
};

_ToolConfig _cfg(String? name) =>
    _toolConfigs[name] ??
    const _ToolConfig(
      Icons.extension_outlined,
      AppThemes.textSecondary,
      '🔧  TOOL CALL',
    );

// ─────────────────────────────────────────────────────────────────────────────

class ToolStepBubble extends StatefulWidget {
  final AgentStep step;
  const ToolStepBubble({super.key, required this.step});

  @override
  State<ToolStepBubble> createState() => _ToolStepBubbleState();
}

class _ToolStepBubbleState extends State<ToolStepBubble>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.step.type == AgentStepType.toolCall) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCall = widget.step.type == AgentStepType.toolCall;
    final isResult = widget.step.type == AgentStepType.toolResult;
    if (!isCall && !isResult) return const SizedBox.shrink();

    final cfg = _cfg(widget.step.toolName);
    final isSuccess = isResult && widget.step.content.startsWith('SUCCESS');
    final isError =
        isResult &&
        (widget.step.content.startsWith('Error') ||
            widget.step.content.startsWith('Failed') ||
            widget.step.content.startsWith('TIMEOUT'));

    final borderColor = isCall
        ? cfg.color.withAlpha(60)
        : isSuccess
        ? AppThemes.accentGreen.withAlpha(40)
        : isError
        ? AppThemes.errorRed.withAlpha(60)
        : AppThemes.dividerColor;

    final bgColor = isCall
        ? AppThemes.surfaceCard
        : isSuccess
        ? AppThemes.surfaceDark
        : isError
        ? AppThemes.errorRed.withAlpha(10)
        : AppThemes.bgDark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vertical timeline bar
          Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 2,
                height: 26,
                decoration: BoxDecoration(
                  color: cfg.color.withAlpha(isCall ? 140 : 60),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: isResult
                  ? () => setState(() => _expanded = !_expanded)
                  : null,
              onLongPress: isResult
                  ? () {
                      Clipboard.setData(
                        ClipboardData(text: widget.step.content),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Result copied'),
                          duration: Duration(seconds: 1),
                          backgroundColor: AppThemes.surfaceCard,
                        ),
                      );
                    }
                  : null,
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (context, child) => Opacity(
                  opacity: isCall ? 0.6 + 0.4 * _pulse.value : 1.0,
                  child: child,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor, width: 0.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(50),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                      if (isCall)
                        BoxShadow(
                          color: cfg.color.withAlpha(10),
                          blurRadius: 15,
                        ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Header row ────────────────────────────────────
                      Row(
                        children: [
                          Icon(cfg.icon, color: cfg.color, size: 15),
                          const SizedBox(width: 8),
                          Text(
                            isCall
                                ? cfg.callLabel
                                : _resultLabel(isSuccess, isError),
                            style: TextStyle(
                              color: isCall
                                  ? cfg.color
                                  : isSuccess
                                  ? AppThemes.accentGreen
                                  : isError
                                  ? AppThemes.errorRed
                                  : AppThemes.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          if (isResult) ...[
                            const Spacer(),
                            Icon(
                              _expanded
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              color: AppThemes.textSecondary,
                              size: 14,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 5),
                      // ── Main content: file path (prominent) or command ─
                      _buildMainContent(isCall, cfg),
                      // ── Result body (collapsible) ─────────────────────
                      if (isResult && _expanded) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D1117),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: SelectableText(
                            widget.step.content,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: Color(0xFFE2E8F0),
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                      // ── Collapsed preview line ─────────────────────────
                      if (isResult &&
                          !_expanded &&
                          widget.step.content.length > 60) ...[
                        const SizedBox(height: 4),
                        Text(
                          _truncate(widget.step.content, 90),
                          style: const TextStyle(
                            color: AppThemes.textSecondary,
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                        Text(
                          'Tap to expand ↓',
                          style: TextStyle(
                            color: cfg.color.withAlpha(160),
                            fontSize: 10,
                          ),
                        ),
                      ],
                      // ── Open project button (build_project success) ────
                      if (isResult &&
                          widget.step.toolName == 'build_project' &&
                          isSuccess)
                        _buildOpenProjectButton(context),
                      // ── Open project button (create_file success) ──────
                      if (isResult &&
                          widget.step.toolName == 'create_file' &&
                          isSuccess)
                        _buildOpenFileAction(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(bool isCall, _ToolConfig cfg) {
    final tool = widget.step.toolName ?? '';
    final isFileOp = [
      'create_file',
      'edit_file',
      'read_file',
      'list_directory',
    ].contains(tool);

    if (isCall && isFileOp) {
      // Show the file path prominently
      return Row(
        children: [
          Text(
            _fileExtIcon(widget.step.content),
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              widget.step.content,
              style: const TextStyle(
                color: AppThemes.textPrimary,
                fontSize: 13,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    return Text(
      widget.step.content.isEmpty
          ? '...'
          : _truncate(widget.step.content, isCall ? 120 : 60),
      style: const TextStyle(color: AppThemes.textPrimary, fontSize: 13),
    );
  }

  Widget _buildOpenProjectButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: TextButton.icon(
        onPressed: () {
          final id =
              widget.step.toolParams?['id']?.toString() ??
              widget.step.toolParams?['name']?.toString() ??
              '';
          if (id.isNotEmpty) context.push('/home/projects/$id');
        },
        icon: const Icon(
          Icons.folder_open,
          size: 15,
          color: AppThemes.accentCyan,
        ),
        label: const Text(
          'Open Workspace',
          style: TextStyle(
            color: AppThemes.accentCyan,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          backgroundColor: AppThemes.accentCyan.withAlpha(20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          side: BorderSide(
            color: AppThemes.accentCyan.withAlpha(50),
            width: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildOpenFileAction() {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 14,
            color: AppThemes.accentGreen,
          ),
          const SizedBox(width: 8),
          Text(
            'File generated',
            style: TextStyle(
              color: AppThemes.accentGreen.withAlpha(200),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _resultLabel(bool isSuccess, bool isError) {
    final name =
        _toolConfigs[widget.step.toolName]?.callLabel.replaceAll(
          RegExp(r'^.+  '),
          '',
        ) ??
        'RESULT';
    if (isSuccess) return '✅  $name — DONE';
    if (isError) return '❌  $name — ERROR';
    return '↩  $name — RESULT';
  }

  String _fileExtIcon(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.dart')) return '🎯';
    if (lower.endsWith('.js') || lower.endsWith('.ts')) return '🟨';
    if (lower.endsWith('.py')) return '🐍';
    if (lower.endsWith('.json')) return '📋';
    if (lower.endsWith('.yaml') || lower.endsWith('.yml')) return '⚙️';
    if (lower.endsWith('.md')) return '📝';
    if (lower.endsWith('.html') || lower.endsWith('.htm')) return '🌐';
    if (lower.endsWith('.css') || lower.endsWith('.scss')) return '🎨';
    if (lower.endsWith('.sh')) return '⚡';
    if (lower.endsWith('.kt') || lower.endsWith('.kts')) return '🟣';
    return '📄';
  }

  String _truncate(String s, int max) =>
      s.length > max ? '${s.substring(0, max)}…' : s;
}
