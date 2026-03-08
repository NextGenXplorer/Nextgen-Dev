import 'dart:async';
import 'dart:io';

class DevServerService {
  final String workingDirectory;
  Process? _activeProcess;
  final _logController = StreamController<String>.broadcast();

  DevServerService({required this.workingDirectory});

  Stream<String> get logStream => _logController.stream;
  bool get isRunning => _activeProcess != null;

  Future<void> startServer(String command, List<String> args) async {
    if (isRunning) {
      throw Exception('Server is already running.');
    }

    _logController.add('Starting dev server: $command ${args.join(' ')}...');

    try {
      _activeProcess = await Process.start(
        command,
        args,
        workingDirectory: workingDirectory,
        runInShell: true,
      );

      _activeProcess!.stdout.listen((data) {
        final message = String.fromCharCodes(data).trim();
        if (message.isNotEmpty) _logController.add(message);
      });

      _activeProcess!.stderr.listen((data) {
        final message = String.fromCharCodes(data).trim();
        if (message.isNotEmpty) _logController.add('ERROR: $message');
      });

      // ignore: unawaited_futures
      _activeProcess!.exitCode.then((code) {
        _logController.add('Server exited with code $code');
        _activeProcess = null;
      });

    } catch (e) {
      _logController.add('Failed to start server: $e');
      _activeProcess = null;
      throw Exception('Process start failed: $e');
    }
  }

  Future<void> stopServer() async {
    if (!isRunning) {
      _logController.add('No active server to stop.');
      return;
    }

    _logController.add('Stopping dev server...');
    _activeProcess!.kill();
    _activeProcess = null;
    _logController.add('Server stopped.');
  }

  void dispose() {
    stopServer();
    _logController.close();
  }
}
