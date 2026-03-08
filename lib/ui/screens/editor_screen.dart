import 'package:flutter/material.dart';
import '../widgets/code_editor_widget.dart';
import '../widgets/terminal_widget.dart';
import '../widgets/file_manager_drawer.dart';

class EditorScreen extends StatelessWidget {
  final String projectId;
  final String filePath;

  const EditorScreen({
    super.key,
    required this.projectId,
    required this.filePath,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Editing: $filePath', style: const TextStyle(fontSize: 14)),
        backgroundColor: const Color(0xFF2D2D2D),
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.play_arrow, color: Colors.green), onPressed: () {}),
          IconButton(icon: const Icon(Icons.save), onPressed: () {}),
        ],
      ),
      drawer: const FileManagerDrawer(),
      body: Column(
        children: [
          // Main Editor Space
          Expanded(
            flex: 3,
            child: CodeEditorWidget(filePath: filePath),
          ),
          // Resizer handle
          Container(height: 1, color: Colors.grey[800]),
          // Integrated Terminal Space
          const Expanded(
            flex: 2,
            child: TerminalWidget(),
          ),
        ],
      ),
    );
  }
}

