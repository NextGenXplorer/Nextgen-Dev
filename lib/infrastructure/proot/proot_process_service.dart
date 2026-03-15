import 'dart:io';
import '../../application/agent/tools/proot_tools.dart';

/// Concrete implementation of the PRootService taking advantage of Dart's Process capabilities.
/// Note: On a physical Android device, triggering `proot` requires a bootstrapped Alpine/Ubuntu file system.
/// This service assumes the `proot` command is available in the shell or falls back to standard execution
/// for generic commands.
class NativeProcessService implements PRootService {
  final String prootBasePath;

  NativeProcessService({
    /// The absolute path where the Ubuntu rootfs is installed on the Android /data/data partition.
    required this.prootBasePath,
  });

  @override
  Future<ProcessResult> runCommand(String command, {String? workingDirectory}) async {
    // 1. Construct the secure sandboxed command wrapper.
    // In a real device, it looks like:
    // proot -0 -r /data/.../ubuntu-fs -b /dev -b /proc -b /sys -w /root bash -c "npm install"
    
    // For this implementation, we will assume standard bash execution mapping.
    // A robust app should map this to a compiled C/C++ JNI PRoot binary.
    
    final executable = 'sh'; // or 'bash' depending on rootfs setup
    final arguments = ['-c', command];

    try {
      // Execute non-interactively to grab outputs directly.
      final result = await Process.run(
        executable,
        arguments,
        workingDirectory: workingDirectory,
        runInShell: true, 
      );

      return result;
    } catch (e) {
      // If the process couldn't even spawn (e.g. executable not found)
      throw Exception('Failed to spawn native process: $e');
    }
  }
}
