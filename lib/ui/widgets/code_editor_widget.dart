import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';

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
    _controller = CodeLineEditingController.fromText(
'''
// Example dart file
void main() {
  print("Hello from \${widget.filePath}");
}
'''
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1E1E1E), // Dark theme background
      child: Column(
        children: [
          // File Tab Bar placeholder
          Container(
            height: 40,
            color: const Color(0xFF2D2D2D),
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
              style: CodeEditorStyle(
                fontSize: 14,
                fontFamily: 'monospace',
              ),
              wordWrap: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String title, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF1E1E1E) : Colors.transparent,
        border: isActive
            ? const Border(top: BorderSide(color: Colors.blueAccent, width: 2))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.grey,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.close, size: 14, color: isActive ? Colors.white : Colors.grey),
        ],
      ),
    );
  }
}
