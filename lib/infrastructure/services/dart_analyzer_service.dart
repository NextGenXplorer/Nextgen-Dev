import 'dart:io';
import 'dart:convert';

class DartAnalyzerService {
  final String workingDirectory;

  DartAnalyzerService({required this.workingDirectory});

  /// Runs `dart analyze --machine` and parses the JSON output to find errors and warnings.
  Future<String> getErrors() async {
    try {
      final result = await Process.run(
        'dart',
        ['analyze', '--machine'],
        workingDirectory: workingDirectory,
        runInShell: true,
      );

      final output = result.stdout.toString().trim();
      if (output.isEmpty) {
        return 'No issues found. Code is clean.';
      }

      // The --machine output is a series of JSON objects separated by newlines or a single JSON string
      final List<String> errorLines = [];
      const delimiter = 'INFO|';
      
      // Basic parse of machine output which looks like:
      // INFO|LINT|CODE|path/to/file.dart|line|col|length|Message
      final lines = output.split('\n');
      for (final line in lines) {
         if (line.isNotEmpty) {
             errorLines.add(line);
         }
      }
      
      return 'Analysis Results:\n${errorLines.join('\n')}';

    } catch (e) {
      return 'Failed to run dart analyzer: $e';
    }
  }

  /// Runs `dart format` to automatically fix indentation and formatting.
  Future<String> format(String filePath) async {
    try {
      final result = await Process.run(
        'dart',
        ['format', filePath],
        workingDirectory: workingDirectory,
        runInShell: true,
      );
      return result.stdout.toString();
    } catch (e) {
      return 'Failed to format file: $e';
    }
  }

  /// Runs `dart fix --apply` to automatically fix standard lint errors.
  Future<String> applyDetailedFixes(String filePath) async {
    try {
      final result = await Process.run(
        'dart',
        ['fix', '--apply', filePath],
        workingDirectory: workingDirectory,
        runInShell: true,
      );
      return result.stdout.toString();
    } catch (e) {
      return 'Failed to apply dart fixes: $e';
    }
  }
}
