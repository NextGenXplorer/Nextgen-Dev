import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

/// Manages the lifecycle of the underlying shell process (proot on Android).
class ProcessBridge {
  Pty? _pty;
  final _stdoutController = StreamController<String>.broadcast();
  bool _isInit = false;

  Stream<String> get outStream => _stdoutController.stream;

  /// Starts the PRoot shell or a platform-appropriate fallback shell.
  Future<void> launch({String? workspacePath}) async {
    if (_isInit) return;

    String executable;
    List<String> args = [];

    if (Platform.isAndroid) {
      try {
        final docDir = await getApplicationDocumentsDirectory();
        final launcher = File('${docDir.path}/proot_launcher.sh');
        final prootBin = File('${docDir.path}/proot');
        final rootfs = Directory('${docDir.path}/ubuntu_rootfs');
        final bashBin = File('${docDir.path}/ubuntu_rootfs/bin/bash');

        if (await launcher.exists() &&
            await prootBin.exists() &&
            await bashBin.exists() &&
            await rootfs.exists()) {
          // Full Ubuntu PRoot environment
          executable = '/bin/sh';
          args = [launcher.path, prootBin.path, rootfs.path, workspacePath ?? ''];
          debugPrint('ProcessBridge: Launching PRoot Ubuntu environment...');
          _stdoutController.add(
            '\x1b[32m⠿ Starting Ubuntu shell...\x1b[0m\r\n',
          );
        } else {
          // Fallback: standard Android shell while setup runs
          executable = '/bin/sh';
          debugPrint(
            'ProcessBridge: proot not ready, using standard shell as fallback.',
          );
          _stdoutController.add(
            '\x1b[33m⚠ Ubuntu environment not ready. Tap + to set up.\x1b[0m\r\n',
          );
        }
      } catch (e) {
        debugPrint('ProcessBridge: path resolution failed: $e');
        executable = '/bin/sh';
      }
    } else if (Platform.isWindows) {
      executable = 'cmd.exe';
    } else {
      executable = '/bin/sh';
    }

    try {
      _pty = Pty.start(
        executable,
        arguments: args,
        environment: {
          'HOME': Platform.isAndroid ? '/root' : (Platform.environment['HOME'] ?? '/root'),
          'TERM': 'xterm-256color',
          'LANG': 'C.UTF-8',
          'PATH': '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin',
        },
        columns: 120,
        rows: 40,
      );

      _pty!.output
          .cast<List<int>>()
          .transform(utf8.decoder)
          .listen(
            (data) => _stdoutController.add(data),
            onError: (e) =>
                debugPrint('ProcessBridge stdout error: $e'),
          );

      _isInit = true;
      debugPrint('ProcessBridge: launched successfully with $executable.');
    } catch (e) {
      debugPrint('ProcessBridge: launch failed: $e');
      _stdoutController.add('\x1b[31m✗ Shell launch failed: $e\x1b[0m\r\n');
    }
  }

  /// Injects text directly into the xterm output stream. Used for
  /// progress messages before the PTY process has started.
  void injectOutput(String data) {
    if (!_stdoutController.isClosed) {
      _stdoutController.add(data);
    }
  }

  /// Writes raw input to the PTY (keyboard → shell).
  void write(String data) {
    if (!_isInit || _pty == null) return;
    final encoded = utf8.encode(data);
    _pty!.write(Uint8List.fromList(encoded));
  }

  /// Sends a full command followed by a newline.
  void exec(String command) => write('$command\n');

  /// Resizes the PTY to match new terminal dimensions.
  void resize({required int columns, required int rows}) {
    _pty?.resize(rows, columns);
  }

  /// Cleanly disposes the PTY process and stream.
  Future<void> dispose() async {
    _pty?.kill();
    _pty = null;
    if (!_stdoutController.isClosed) {
      await _stdoutController.close();
    }
    _isInit = false;
  }
}
