import 'dart:io';
import '../../../domain/agent/agent_tool.dart';

class ReadFileTool implements AgentTool {
  @override
  String get name => 'read_file';

  @override
  String get description => 'Reads the complete contents of a file at the given absolute path. Use this to understand code before modifying it.';

  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'path': {
        'type': 'string',
        'description': 'The absolute path to the file to read',
      }
    },
    'required': ['path'],
  };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final path = arguments['path'] as String;
    final file = File(path);
    
    if (!await file.exists()) {
      return 'Error: File does not exist at path: $path';
    }

    try {
      final content = await file.readAsString();
      return content;
    } catch (e) {
      return 'Error reading file: $e';
    }
  }
}

class WriteFileTool implements AgentTool {
  @override
  String get name => 'write_file';

  @override
  String get description => 'Writes the given content to a file. Overwrites the file if it exists. Creates it if it does not. Use this to write code or save data.';

  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'path': {
        'type': 'string',
        'description': 'The absolute path to the file to write',
      },
      'content': {
        'type': 'string',
        'description': 'The raw text/code content to write into the file',
      }
    },
    'required': ['path', 'content'],
  };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final path = arguments['path'] as String;
    final content = arguments['content'] as String;
    
    try {
      final file = File(path);
      
      // Ensure parent directories exist
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }
      
      await file.writeAsString(content);
      return 'Success: Wrote ${content.length} characters to $path';
    } catch (e) {
      return 'Error writing file: $e';
    }
  }
}
