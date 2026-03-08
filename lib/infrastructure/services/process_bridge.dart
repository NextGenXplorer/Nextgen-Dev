import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

/// Manages the lifecycle of the underlying shell process (simulate PRoot on Android).
class ProcessBridge {
  Pty? _pty;
  final _stdoutController = StreamController<String>.broadcast();
  bool _isInit = false;

  Stream<String> get outStream => _stdoutController.stream;

  /// Starts the PRoot shell (or local shell if testing on desktop)
  Future<void> launch() async {
    if (_isInit) return;
    
    // Fallback to local shell if not on Android
    String executable = Platform.isWindows ? 'cmd.exe' : 'sh';
    List<String> args = [];

    if (Platform.isAndroid) {
      try {
        final docDir = await getApplicationDocumentsDirectory();
        final launcher = File('${docDir.path}/proot_launcher.sh');
        final prootBin = File('${docDir.path}/proot');
        final rootfs = Directory('${docDir.path}/ubuntu_rootfs');

        if (await launcher.exists() && await prootBin.exists() && await rootfs.exists()) {
          executable = 'sh';
          args = [launcher.path, prootBin.path, rootfs.path];
          debugPrint('ProcessBridge: Launching PRoot Ubuntu Environment...');
        } else {
          executable = 'sh';
          debugPrint('ProcessBridge: PRoot components missing, fallback to standard shell.');
        }
      } catch (e) {
        debugPrint('Failed to initialize PRoot paths: $e');
        executable = 'sh';
      }
    }

    try {
      _pty = Pty.start(
        executable,
        arguments: args,
        environment: Map.from(Platform.environment),
      );

      _pty!.output.cast<List<int>>().transform(const SystemEncoding().decoder).listen((data) {
        _stdoutController.add(data);
      });

      _isInit = true;
      debugPrint('ProcessBridge launched successfully.');
    } catch (e) {
      debugPrint('Error launching ProcessBridge: $e');
      rethrow;
    }
  }

  /// Writes raw input directly to the PTY (e.g., from xterm keyboard)
  void write(String data) {
    if (!_isInit || _pty == null) return;
    final encoded = const SystemEncoding().encode(data);
    _pty!.write(Uint8List.fromList(encoded));
  }

  /// Executes a full command with a newline
  void exec(String command) {
    write('$command\n');
  }

  /// Cleanly terminates the child processes
  Future<void> dispose() async {
    if (_pty != null) {
      _pty!.kill();
      _pty = null;
    }
    await _stdoutController.close();
    _isInit = false;
  }
}

