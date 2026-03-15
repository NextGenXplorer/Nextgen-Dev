import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import '../../application/providers/storage_providers.dart';
import '../../infrastructure/services/project_service.dart';
import '../themes.dart';

// ── Live file scan provider ──────────────────────────────────────────────────

/// Scans the project folder on disk every time it's read.
/// Returns a tree of [FileNode]s sorted: folders first, then files.
final projectFilesProvider =
    FutureProvider.family<List<FileNode>, String>((ref, projectId) async {
  final manager = ref.watch(workspaceManagerProvider);
  final root = await manager.getWorkspaceRootPath();
  final projectPath = '$root/$projectId';
  final dir = Directory(projectPath);
  if (!await dir.exists()) return [];
  return _scanDirectory(dir, projectPath);
});

Future<List<FileNode>> _scanDirectory(Directory dir, String rootPath) async {
  final List<FileNode> nodes = [];
  await for (final entity in dir.list(followLinks: false)) {
    final rel = p.relative(entity.path, from: rootPath);
    if (entity is Directory) {
      final children = await _scanDirectory(entity, rootPath);
      nodes.add(FileNode.folder(name: p.basename(entity.path), relativePath: rel, children: children));
    } else if (entity is File) {
      nodes.add(FileNode.file(name: p.basename(entity.path), relativePath: rel));
    }
  }
  nodes.sort((a, b) {
    if (a.isFolder && !b.isFolder) return -1;
    if (!a.isFolder && b.isFolder) return 1;
    return a.name.compareTo(b.name);
  });
  return nodes;
}

class FileNode {
  final String name;
  final String relativePath;
  final bool isFolder;
  final List<FileNode> children;

  const FileNode({
    required this.name,
    required this.relativePath,
    required this.isFolder,
    this.children = const [],
  });

  factory FileNode.file({required String name, required String relativePath}) =>
      FileNode(name: name, relativePath: relativePath, isFolder: false);

  factory FileNode.folder({
    required String name,
    required String relativePath,
    List<FileNode> children = const [],
  }) =>
      FileNode(name: name, relativePath: relativePath, isFolder: true, children: children);
}

// ── Screen ───────────────────────────────────────────────────────────────────

class ProjectExplorerScreen extends ConsumerStatefulWidget {
  final String id;
  const ProjectExplorerScreen({super.key, required this.id});

  @override
  ConsumerState<ProjectExplorerScreen> createState() =>
      _ProjectExplorerScreenState();
}

class _ProjectExplorerScreenState extends ConsumerState<ProjectExplorerScreen> {
  final Set<String> _expandedFolders = {};

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(projectListProvider);
    final filesAsync = ref.watch(projectFilesProvider(widget.id));

    return Scaffold(
      backgroundColor: AppThemes.bgDark,
      appBar: AppBar(
        backgroundColor: AppThemes.bgDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppThemes.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: projectsAsync.maybeWhen(
          data: (projects) {
            final proj = projects.cast<dynamic>().firstWhere(
              (p) => p.id == widget.id,
              orElse: () => null,
            );
            return Text(
              proj?.name ?? 'Project Explorer',
              style: const TextStyle(color: AppThemes.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
            );
          },
          orElse: () => const Text('Project Explorer', style: TextStyle(color: AppThemes.textPrimary)),
        ),
        actions: [
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppThemes.textSecondary, size: 20),
            tooltip: 'Refresh files',
            onPressed: () => ref.invalidate(projectFilesProvider(widget.id)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Build progress (if project has tasks)
          projectsAsync.maybeWhen(
            data: (projects) {
              final proj = projects.cast<dynamic>().firstWhere(
                (p) => p.id == widget.id,
                orElse: () => null,
              );
              if (proj != null && (proj.tasks as List).isNotEmpty) {
                return _buildTaskDashboard(proj);
              }
              return const SizedBox.shrink();
            },
            orElse: () => const SizedBox.shrink(),
          ),
          // Live file tree
          Expanded(
            child: filesAsync.when(
              data: (nodes) => nodes.isEmpty
                  ? _buildEmptyState()
                  : _buildFileTree(nodes),
              loading: () => const Center(child: CircularProgressIndicator(color: AppThemes.accentCyan)),
              error: (e, _) => Center(
                child: Text('Failed to scan files:\n$e',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppThemes.errorRed)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Task Dashboard ────────────────────────────────────────────────────────
  Widget _buildTaskDashboard(dynamic project) {
    final tasks = project.tasks as List;
    final done = tasks.where((t) => t.status.name == 'done').length;
    final progress = tasks.isNotEmpty ? done / tasks.length : 0.0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppThemes.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppThemes.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Build Progress',
                  style: TextStyle(color: AppThemes.textPrimary, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('${(progress * 100).toInt()}%',
                  style: const TextStyle(color: AppThemes.accentCyan, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppThemes.bgDark,
              color: AppThemes.accentCyan,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty State ───────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open_rounded, size: 72, color: AppThemes.textSecondary.withOpacity(0.25)),
          const SizedBox(height: 16),
          const Text('No files yet', style: TextStyle(color: AppThemes.textSecondary, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('Ask the agent to build the project',
              style: TextStyle(color: AppThemes.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  // ── File Tree ─────────────────────────────────────────────────────────────
  Widget _buildFileTree(List<FileNode> nodes) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      children: _buildNodes(nodes, 0),
    );
  }

  List<Widget> _buildNodes(List<FileNode> nodes, int depth) {
    final widgets = <Widget>[];
    for (final node in nodes) {
      widgets.add(_buildNode(node, depth));
    }
    return widgets;
  }

  Widget _buildNode(FileNode node, int depth) {
    final indent = depth * 20.0;
    if (node.isFolder) {
      final isExpanded = _expandedFolders.contains(node.relativePath);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() {
              if (isExpanded) {
                _expandedFolders.remove(node.relativePath);
              } else {
                _expandedFolders.add(node.relativePath);
              }
            }),
            child: Padding(
              padding: EdgeInsets.only(left: 8 + indent, right: 8, top: 10, bottom: 10),
              child: Row(
                children: [
                  Icon(
                    isExpanded ? Icons.folder_open_rounded : Icons.folder_rounded,
                    size: 20,
                    color: const Color(0xFFE8B343),
                  ),
                  const SizedBox(width: 10),
                  Text(node.name,
                      style: const TextStyle(
                          color: AppThemes.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                  const Spacer(),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: AppThemes.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded && node.children.isNotEmpty)
            Column(children: _buildNodes(node.children, depth + 1)),
        ],
      );
    } else {
      return InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => context.push(
            '/home/projects/${widget.id}/editor/${Uri.encodeComponent(node.relativePath)}'),
        child: Padding(
          padding: EdgeInsets.only(left: 8 + indent, right: 8, top: 8, bottom: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _fileColor(node.name).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_fileIcon(node.name), size: 16, color: _fileColor(node.name)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(node.name,
                    style: const TextStyle(color: AppThemes.textPrimary, fontSize: 14)),
              ),
              const Icon(Icons.chevron_right, size: 16, color: AppThemes.textSecondary),
            ],
          ),
        ),
      );
    }
  }

  IconData _fileIcon(String name) {
    if (name.endsWith('.dart')) return Icons.code;
    if (name.endsWith('.js') || name.endsWith('.ts')) return Icons.javascript;
    if (name.endsWith('.html')) return Icons.html;
    if (name.endsWith('.css')) return Icons.css;
    if (name.endsWith('.md')) return Icons.description_outlined;
    if (name.endsWith('.json')) return Icons.data_object;
    if (name.endsWith('.yaml') || name.endsWith('.yml')) return Icons.settings;
    if (name.endsWith('.sh')) return Icons.terminal;
    return Icons.insert_drive_file_outlined;
  }

  Color _fileColor(String name) {
    if (name.endsWith('.dart')) return Colors.blue;
    if (name.endsWith('.js') || name.endsWith('.ts')) return Colors.yellow;
    if (name.endsWith('.html')) return Colors.orange;
    if (name.endsWith('.css')) return Colors.blueAccent;
    if (name.endsWith('.md')) return Colors.teal;
    if (name.endsWith('.json')) return const Color(0xFFF0C27F);
    if (name.endsWith('.yaml') || name.endsWith('.yml')) return Colors.purple;
    return AppThemes.textSecondary;
  }
}
