import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'agent_tool.dart';

/// Executes a shell command and returns its output.
/// Enforces a 60-second hard timeout and truncates output to 4000 chars.
///
/// Tool call format:
///   {"name": "run_terminal_command", "command": "flutter pub get", "working_directory": "/abs/path"}
class TerminalTool implements AgentTool {
  final String? activeProjectPath;

  TerminalTool({this.activeProjectPath});
  @override
  String get name => 'run_terminal_command';

  @override
  String get displayName => 'Run Command';

  @override
  String get uiIcon => 'terminal';

  @override
  String get description =>
      'Executes a shell command (e.g., flutter pub get, npm install, git status) '
      'and returns stdout/stderr. Has a 60-second timeout.';

  @override
  Future<String> execute(Map<String, dynamic> params) async {
    final command = params['command'] as String?;
    final workingDirectory = params['working_directory'] as String?;

    if (command == null || command.trim().isEmpty) {
      return 'Error: No command provided.';
    }

    try {
      // Resolve working directory
      String cwd = workingDirectory?.trim() ?? '';
      if (cwd.isEmpty) {
        if (activeProjectPath != null && activeProjectPath!.isNotEmpty) {
          cwd = activeProjectPath!;
        } else {
          final docDir = await getApplicationDocumentsDirectory();
          cwd = '${docDir.path}/Projects';
        }
        final dir = Directory(cwd);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
      }

      final isWindows = Platform.isWindows;
      final executable = isWindows ? 'cmd.exe' : 'sh';
      final args = isWindows ? ['/c', command] : ['-c', command];

      // Run with hard 60-second timeout
      ProcessResult result;
      try {
        result =
            await Process.run(
              executable,
              args,
              workingDirectory: cwd,
              runInShell: true,
            ).timeout(
              const Duration(seconds: 60),
              onTimeout: () => ProcessResult(
                -1,
                1,
                '',
                'TIMEOUT: Command "$command" exceeded 60 seconds.',
              ),
            );
      } on TimeoutException {
        return 'TIMEOUT: "$command" took longer than 60 seconds and was killed.';
      }

      final rawStdout = result.stdout.toString().trim();
      final rawStderr = result.stderr.toString().trim();
      final exitCode = result.exitCode;

      // Truncate to avoid overflowing the AI context window
      const maxLen = 4000;
      String trunc(String s) => s.length > maxLen
          ? '${s.substring(0, maxLen)}\n... [truncated ${s.length - maxLen} more chars]'
          : s;

      final sb = StringBuffer('Exit Code: $exitCode\n');
      if (rawStdout.isNotEmpty) sb.write('STDOUT:\n${trunc(rawStdout)}\n');
      if (rawStderr.isNotEmpty) sb.write('STDERR:\n${trunc(rawStderr)}\n');
      if (rawStdout.isEmpty && rawStderr.isEmpty) sb.write('(no output)\n');

      // Add a hint on non-zero exit
      if (exitCode != 0 && exitCode != -1) {
        sb.write(
          '\nHint: Non-zero exit code indicates an error. '
          'Analyze the STDERR output and fix the issue before continuing.',
        );
      }

      return sb.toString();
    } catch (e) {
      return 'Failed to execute command: $e';
    }
  }
}
