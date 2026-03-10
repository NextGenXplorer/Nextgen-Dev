import 'dart:async';
import 'dart:io';

class LogMonitorService {
  Process? _logcatProcess;
  final StreamController<String> _errorStreamController = StreamController<String>.broadcast();
  
  Stream<String> get errorStream => _errorStreamController.stream;

  Future<void> startMonitoring() async {
    if (_logcatProcess != null) return; // Already running

    try {
      // Clear previous logs
      await Process.run('adb', ['logcat', '-c'], runInShell: true);

      // Start logcat, filtering for Errors and Fatal exceptions
      // *:E means all tags, Error level and above
      _logcatProcess = await Process.start(
        'adb', 
        ['logcat', '*:E'],
        runInShell: true
      );

      _logcatProcess!.stdout.transform(SystemEncoding().decoder).listen((data) {
        _processLogChunk(data);
      });

      _logcatProcess!.stderr.transform(SystemEncoding().decoder).listen((data) {
        // adb errors usually go to stderr
        print('LogMonitorService ADB Error: \$data');
      });

    } catch (e) {
      print('Failed to start LogMonitorService: \$e');
    }
  }

  void stopMonitoring() {
    _logcatProcess?.kill();
    _logcatProcess = null;
  }

  void _processLogChunk(String chunk) {
    // Only capture lines that look like actual app crashes or unhandled exceptions.
    // We can refine this regex based on standard Flutter/Android crash signatures.
    final lines = chunk.split('\\n');
    for (final line in lines) {
      if (line.contains('Exception') || 
          line.contains('Error') || 
          line.contains('FATAL EXCEPTION') ||
          line.contains('FlutterError')) {
          
        if (line.trim().isNotEmpty) {
           _errorStreamController.add(line.trim());
        }
      }
    }
  }

  void dispose() {
    stopMonitoring();
    _errorStreamController.close();
  }
}
