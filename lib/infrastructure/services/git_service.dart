import 'dart:io';

class GitService {
  final String workingDirectory;

  GitService({required this.workingDirectory});

  Future<String> init() async {
    return _runGitCommand(['init']);
  }

  Future<String> addAll() async {
    return _runGitCommand(['add', '.']);
  }

  Future<String> commit(String message) async {
    return _runGitCommand(['commit', '-m', message]);
  }

  Future<String> push(String remote, String branch) async {
    return _runGitCommand(['push', remote, branch]);
  }

  Future<String> status() async {
    return _runGitCommand(['status']);
  }

  Future<String> log({int count = 5}) async {
    return _runGitCommand(['log', '-n', count.toString(), '--oneline']);
  }

  Future<String> resetHard({String commit = 'HEAD'}) async {
    return _runGitCommand(['reset', '--hard', commit]);
  }

  Future<String> restore(String filePath) async {
    return _runGitCommand(['restore', filePath]);
  }

  Future<String> _runGitCommand(List<String> args) async {
    try {
      final result = await Process.run(
        'git',
        args,
        workingDirectory: workingDirectory,
        runInShell: true,
      );
      if (result.exitCode != 0) {
        throw Exception('Git Error: ${result.stderr}');
      }
      return result.stdout.toString();
    } catch (e) {
      throw Exception('Failed to run git command: $e');
    }
  }
}
