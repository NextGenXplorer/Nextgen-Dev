import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';
import '../themes.dart';

class CodeEditorWidget extends StatefulWidget {
  final String filePath;

  const CodeEditorWidget({super.key, required this.filePath});

  @override
  State<CodeEditorWidget> createState() => _CodeEditorWidgetState();
}

class _CodeEditorWidgetState extends State<CodeEditorWidget> {
  late final CodeLineEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = CodeLineEditingController.fromText('''
// Example dart file
void main() {
  print("Hello from \${widget.filePath}");
}
''');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppThemes.bgDark,
      child: Column(
        children: [
          // File Tab Bar placeholder
          Container(
            height: 44,
            color: AppThemes.surfaceDark,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildTab(widget.filePath, true),
                _buildTab('utils.dart', false),
              ],
            ),
          ),
          // Editor Area placeholder
          Expanded(
            child: CodeEditor(
              controller: _controller,
              style: CodeEditorStyle(fontSize: 14, fontFamily: 'monospace'),
              wordWrap: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String title, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      margin: const EdgeInsets.only(top: 6, right: 2),
      decoration: BoxDecoration(
        color: isActive ? AppThemes.bgDark : Colors.transparent,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
        border: isActive
            ? Border.all(color: AppThemes.dividerColor, width: 1)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              color: isActive ? AppThemes.accentCyan : AppThemes.textSecondary,
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.close,
            size: 14,
            color: isActive ? AppThemes.textPrimary : AppThemes.textSecondary,
          ),
        ],
      ),
    );
  }
}
