import 'dart:io';
import 'package:path/path.dart' as p;
import '../storage/workspace_manager.dart';
import 'agent_tool.dart';

/// Lists the contents of a directory on the filesystem.
class ListDirectoryTool implements AgentTool {
  final WorkspaceManager _workspaceManager;
  ListDirectoryTool(this._workspaceManager);

  // Directories to always skip
  static const _skipDirs = {
    'build',
    '.dart_tool',
    '.git',
    'node_modules',
    '.gradle',
    '__pycache__',
    '.idea',
    '.vs',
  };

  @override
  String get name => 'list_directory';

  @override
  String get displayName => 'List Directory';

  @override
  String get uiIcon => 'folder_open';

  @override
  String get description =>
      'Lists files and subdirectories at the given path. '
      'Returns a tree-style listing.';

  @override
  Future<String> execute(Map<String, dynamic> params) async {
    final rawPath = params['path'] as String? ?? '.';

    try {
      final absolutePath = await _workspaceManager.resolvePath(rawPath);
      Directory dir = Directory(absolutePath);

      if (!await dir.exists()) {
        return 'Error: Directory not found: projects/$rawPath. Resolved: ${dir.path}';
      }

      final sb = StringBuffer();
      sb.writeln('📁 $rawPath/');
      sb.writeln();

      final entities = dir.listSync()
        ..sort((a, b) {
          final aIsDir = a is Directory;
          final bIsDir = b is Directory;
          if (aIsDir && !bIsDir) return -1;
          if (!aIsDir && bIsDir) return 1;
          return p.basename(a.path).compareTo(p.basename(b.path));
        });

      int dirCount = 0;
      int fileCount = 0;

      for (final entity in entities) {
        final name = p.basename(entity.path);

        if (entity is Directory) {
          if (_skipDirs.contains(name)) continue;
          dirCount++;
          sb.writeln('  📂 $name/');
        } else if (entity is File) {
          fileCount++;
          final ext = p.extension(name).toLowerCase();
          final icon = _iconForExt(ext);
          final size = await entity.length();
          sb.writeln('  $icon $name  (${_formatSize(size)})');
        }
      }

      sb.writeln('\n$dirCount director${dirCount == 1 ? 'y' : 'ies'}, $fileCount file${fileCount == 1 ? '' : 's'}');
      return sb.toString();
    } catch (e) {
      return 'Error listing directory: $e';
    }
  }

  String _iconForExt(String ext) {
    switch (ext) {
      case '.dart': return '🎯';
      case '.js':
      case '.ts': return '🟨';
      case '.json': return '📋';
      case '.yaml':
      case '.yml': return '⚙️';
      case '.md': return '📝';
      default: return '📄';
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}
