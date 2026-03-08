import 'package:flutter/material.dart';
import '../../domain/models/agent_step.dart';
import '../themes.dart';

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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left line indicator
          Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 2,
                height: 28,
                color: isCall
                    ? AppThemes.accentBlue.withAlpha(120)
                    : AppThemes.textSecondary.withAlpha(60),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: isResult
                  ? () => setState(() => _expanded = !_expanded)
                  : null,
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (context, child) => Opacity(
                  opacity: isCall ? 0.6 + 0.4 * _pulse.value : 1.0,
                  child: child,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isCall
                        ? AppThemes.accentBlue.withAlpha(15)
                        : AppThemes.surfaceCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isCall
                          ? AppThemes.accentBlue.withAlpha(60)
                          : AppThemes.dividerColor,
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Icon
                      _buildIcon(isCall),
                      const SizedBox(width: 10),
                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isCall
                                  ? _callLabel()
                                  : '${_toolDisplayName()} result',
                              style: TextStyle(
                                color: isCall
                                    ? AppThemes.accentBlue
                                    : AppThemes.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isCall
                                  ? widget.step.content
                                  : (_expanded
                                      ? widget.step.content
                                      : _truncate(widget.step.content, 80)),
                              style: const TextStyle(
                                color: AppThemes.textPrimary,
                                fontSize: 13,
                              ),
                            ),
                            if (isResult && widget.step.content.length > 80)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  _expanded ? 'Show less ↑' : 'Show more ↓',
                                  style: const TextStyle(
                                    color: AppThemes.accentBlue,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
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

  Widget _buildIcon(bool isCall) {
    final tool = widget.step.toolName ?? '';
    IconData icon;
    Color color;

    if (isCall) {
      icon = tool == 'web_search' ? Icons.search : Icons.link_outlined;
      color = AppThemes.accentBlue;
    } else {
      icon = Icons.check_circle_outline;
      color = AppThemes.textSecondary;
    }

    return Icon(icon, color: color, size: 16);
  }

  String _callLabel() {
    switch (widget.step.toolName) {
      case 'web_search':
        return '🔍  SEARCHING THE WEB';
      case 'read_url':
        return '📄  READING PAGE';
      default:
        return '🔧  CALLING TOOL';
    }
  }

  String _toolDisplayName() {
    switch (widget.step.toolName) {
      case 'web_search':
        return 'Search';
      case 'read_url':
        return 'Page';
      default:
        return widget.step.toolName ?? 'Tool';
    }
  }

  String _truncate(String s, int max) =>
      s.length > max ? '${s.substring(0, max)}...' : s;
}
