import 'dart:io';
import '../../../domain/agent/agent_tool.dart';

/// Abstract service that bridges to the native PRoot process.
abstract class PRootService {
  Future<ProcessResult> runCommand(String command, {String? workingDirectory});
}

class PRootRunCommandTool implements AgentTool {
  final PRootService prootService;

  PRootRunCommandTool({required this.prootService});

  @override
  String get name => 'run_command';

  @override
  String get description => 
      'Executes a bash command inside the PRoot Ubuntu sandbox. '
      'Returns the stdout, stderr, and exit code. Use this for running '
      'npm, flutter build, git, or testing code. Commands run securely.';

  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'command': {
        'type': 'string',
        'description': 'The exact bash command string to execute.',
      },
      'working_dir': {
        'type': 'string',
        'description': 'Optional absolute path to run the command from.',
      }
    },
    'required': ['command'],
  };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final command = arguments['command'] as String;
    final workingDir = arguments['working_dir'] as String?;
    
    try {
      final result = await prootService.runCommand(
        command, 
        workingDirectory: workingDir
      );

      final buffer = StringBuffer();
      buffer.writeln('Exit Code: ${result.exitCode}');
      
      if (result.stdout.toString().isNotEmpty) {
        // Truncate massively long stdout to prevent context window explosion
        final stdout = result.stdout.toString();
        final truncatedStdout = stdout.length > 5000 
            ? stdout.substring(stdout.length - 5000) 
            : stdout;
        buffer.writeln('--- STDOUT ---');
        buffer.writeln(truncatedStdout);
      }
      
      if (result.stderr.toString().isNotEmpty) {
        buffer.writeln('--- STDERR ---');
        buffer.writeln(result.stderr);
      }

      return buffer.toString();
    } catch (e) {
      return 'Execution Failed: $e';
    }
  }
}
