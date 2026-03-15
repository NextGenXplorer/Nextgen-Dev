import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../application/agent/tools/proot_tools.dart';

/// An enterprise-grade implementation of the PRoot sandbox execution bridge for Android.
/// This guarantees the Ubuntu environment runs perfectly by defining explicit volume mounts, 
/// injecting critical environment variables, and handling process failures natively.
class PerfectPRootService implements PRootService {
  /// The absolute path to the extracted Ubuntu rootfs (e.g. /data/user/0/com.your.app/files/ubuntu-fs)
  final String rootfsPath;
  
  /// The absolute path to the compiled `proot` binary shipped with your app.
  final String prootBinaryPath;
  
  /// The public Workspace directory we requested permissions for earlier
  /// (e.g. /storage/emulated/0/Documents/Mobile_AI_IDE_Projects)
  final String publicWorkspacePath;

  PerfectPRootService({
    required this.rootfsPath,
    required this.prootBinaryPath,
    required this.publicWorkspacePath,
  });

  @override
  Future<ProcessResult> runCommand(String command, {String? workingDirectory}) async {
    // 1. Validate the environment exists before attempting to run it.
    if (!await File(prootBinaryPath).exists()) {
      throw Exception('CRITICAL ERROR: proot binary not found at $prootBinaryPath. Ensure it is extracted during app boot.');
    }
    if (!await Directory(rootfsPath).exists()) {
      throw Exception('CRITICAL ERROR: Ubuntu rootfs not found at $rootfsPath. Missing bootstrap phase?');
    }

    // 2. Build the complex, secure proot execution arguments.
    final prootArgs = <String>[
      '--link2symlink',               // Crucial for fake rooting Android
      '-0',                           // Fake root user ID
      '-r', rootfsPath,               // Mount the Ubuntu filesystem as root (/)
      
      // Essential system mounts required for node, network, and apt to function
      '-b', '/dev',
      '-b', '/proc',
      '-b', '/sys',
      
      // Mount the Android DNS resolution so apt and curl can connect to the internet
      '-b', '/system/etc/resolv.conf:/etc/resolv.conf',
      
      // 3. Mount the public accessible workspace
      // This is the true magic: Web projects created here are visible to the user's File Manager!
      '-b', '$publicWorkspacePath:/workspace',
      
      // Determine working directory inside the Ubuntu sandbox
      '-w', workingDirectory ?? '/workspace',
      
      // Set pristine environment variables
      '/usr/bin/env',
      '-i',
      'HOME=/root',
      'PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin',
      'TERM=xterm-256color',
      'LANG=en_US.UTF-8',
      
      // Finally, the command the Agent wants to run
      '/bin/bash',
      '-l',
      '-c',
      command
    ];

    debugPrint('Executing perfectly mapped PRoot command: \$ $command');

    try {
      // 4. Spawn the process securely
      final result = await Process.run(
        prootBinaryPath,
        prootArgs,
        // Do not use runInShell on Android when calling a direct binary payload
        runInShell: false, 
      );

      return result;
    } catch (e) {
      debugPrint('PRoot execution catastrophic failure: $e');
      throw Exception('Failed to spawn PRoot execution process: $e');
    }
  }
}
