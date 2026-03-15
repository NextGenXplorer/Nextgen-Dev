import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'agent_tool.dart';

/// Installs a package or dependency for a project.
/// Tool call format:
/// {"name": "install_package", "package": "axios", "manager": "npm", "project_path": "/abs/path"}
///
/// Supported package managers: npm, yarn, pip, pub, flutter_pub
class InstallPackageTool implements AgentTool {
  @override
  String get name => 'install_package';

  @override
  String get displayName => 'Install Package';

  @override
  String get uiIcon => 'download_for_offline';

  @override
  String get description =>
      'Installs a dependency/package into a project. '
      'Supported managers: npm, yarn, pip, pub (Dart), flutter. '
      'Example: {"name": "install_package", "package": "http", "manager": "flutter", "project_path": "/path/to/project"}';

  @override
  Future<String> execute(Map<String, dynamic> params) async {
    final package = params['package'] as String?;
    final manager = (params['manager'] as String? ?? 'npm').toLowerCase();
    final rawProjectPath = params['project_path'] as String?;

    if (package == null || package.trim().isEmpty) {
      return 'Error: No package name provided.';
    }

    try {
      // Resolve working directory
      String cwd;
      if (rawProjectPath != null && rawProjectPath.isNotEmpty) {
        cwd = rawProjectPath;
      } else {
        final docDir = await getApplicationDocumentsDirectory();
        cwd = '${docDir.path}/Projects';
      }

      // Make sure directory exists
      final dir = Directory(cwd);
      if (!await dir.exists()) {
        return 'Error: Project path does not exist: $cwd';
      }

      // Build the install command based on package manager
      final String command;
      switch (manager) {
        case 'npm':
          command = 'npm install $package';
          break;
        case 'yarn':
          command = 'yarn add $package';
          break;
        case 'pip':
        case 'pip3':
          command = 'pip3 install $package';
          break;
        case 'pub':
        case 'dart_pub':
          command = 'dart pub add $package';
          break;
        case 'flutter':
        case 'flutter_pub':
          command = 'flutter pub add $package';
          break;
        default:
          return 'Error: Unknown package manager "$manager". Use: npm, yarn, pip, pub, or flutter.';
      }

      final isWindows = Platform.isWindows;
      final executable = isWindows ? 'cmd.exe' : 'sh';
      final args = isWindows ? ['/c', command] : ['-c', command];

      final result =
          await Process.run(
            executable,
            args,
            workingDirectory: cwd,
            runInShell: true,
          ).timeout(
            const Duration(seconds: 120),
            onTimeout: () => ProcessResult(
              -1,
              1,
              '',
              'Timeout: Package installation took too long.',
            ),
          );

      final stdout = result.stdout.toString().trim();
      final stderr = result.stderr.toString().trim();
      final exitCode = result.exitCode;

      if (exitCode == 0) {
        return 'SUCCESS: Installed "$package" via $manager.\n'
            '${stdout.isNotEmpty ? "Output:\n${stdout.substring(0, stdout.length.clamp(0, 2000))}" : ""}';
      } else {
        return 'FAILED (exit $exitCode): Could not install "$package" via $manager.\n'
            '${stderr.isNotEmpty ? "Error:\n${stderr.substring(0, stderr.length.clamp(0, 2000))}" : ""}';
      }
    } catch (e) {
      return 'Error installing package: $e';
    }
  }
}
