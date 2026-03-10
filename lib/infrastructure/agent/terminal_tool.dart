import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'agent_tool.dart';

class TerminalTool implements AgentTool {
  @override
  String get name => 'run_terminal_command';
  
  @override
  String get displayName => 'Run Command';
  
  @override
  String get uiIcon => 'terminal';
  
  @override
  String get description => 'Executes shell commands (e.g., flutter build, npm install) and returns the output.';

  @override
  Future<String> execute(Map<String, dynamic> params) async {
    final command = params['command'] as String?;
    final workingDirectory = params['working_directory'] as String?;
    
    if (command == null || command.isEmpty) {
      return 'Error: No command provided.';
    }

    try {
      // Determine working directory, default to app doc dir / Projects if not provided
      String cwd = workingDirectory ?? '';
      if (cwd.isEmpty) {
          final docDir = await getApplicationDocumentsDirectory();
          cwd = '${docDir.path}/Projects';
          // Ensure directory exists
          final dir = Directory(cwd);
          if (!await dir.exists()) {
             await dir.create(recursive: true);
          }
      }

      // Split command into executable and arguments
      // Note: This is an overly simple split and will fail on quoted arguments with spaces.
      // For a truly robust agent, a proper shell parser is needed, or we rely on shell context.
      // Easiest is to run the command via the system shell.

      final isWindows = Platform.isWindows;
      final executable = isWindows ? 'cmd.exe' : 'sh';
      final args = isWindows ? ['/c', command] : ['-c', command];

      final result = await Process.run(
        executable,
        args,
        workingDirectory: cwd,
        runInShell: true, 
      );

      final stdout = result.stdout.toString().trim();
      final stderr = result.stderr.toString().trim();
      final exitCode = result.exitCode;

      String output = 'Exit Code: $exitCode\n';
      if (stdout.isNotEmpty) {
        output += 'STDOUT:\n$stdout\n';
      }
      if (stderr.isNotEmpty) {
        output += 'STDERR:\n$stderr\n';
      }

      return output;
    } catch (e) {
      return 'Failed to execute command: \$e';
    }
  }
}
