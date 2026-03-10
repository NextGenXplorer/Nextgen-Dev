import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'agent_tool.dart';

class ReadFileTool implements AgentTool {
  @override
  String get name => 'read_file';
  
  @override
  String get displayName => 'Read File';
  
  @override
  String get uiIcon => 'description';
  
  @override
  String get description => 'Reads the contents of a specific file on the file system.';

  @override
  Future<String> execute(Map<String, dynamic> params) async {
    final path = params['path'] as String?;
    
    if (path == null || path.isEmpty) {
      return 'Error: No file path provided.';
    }

    try {
      // Determine file path relative to projects if not absolute
      File file = File(path);
      
      if (!file.isAbsolute) {
        final docDir = await getApplicationDocumentsDirectory();
        file = File('\${docDir.path}/Projects/\$path');
      }

      if (!await file.exists()) {
        return 'Error: File not found at \${file.path}';
      }

      final content = await file.readAsString();
      
      // Optionally truncate if too large, but for AI we usually want the whole file
      return 'File Content:\n```\n\$content\n```';
    } catch (e) {
      return 'Failed to read file: \$e';
    }
  }
}
