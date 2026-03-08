import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../infrastructure/services/project_service.dart';
import '../themes.dart';

class ProjectExplorerScreen extends ConsumerWidget {
  final String id;
  const ProjectExplorerScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectListProvider);

    return Scaffold(
      backgroundColor: AppThemes.bgDark,
      appBar: AppBar(
        backgroundColor: AppThemes.bgDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppThemes.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: projectsAsync.when(
          data: (projects) {
            final project = projects.firstWhere(
              (p) => p.id == id,
              orElse: () => projects.first,
            );
            return Text(
              project.name,
              style: const TextStyle(
                color: AppThemes.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            );
          },
          loading: () => const Text('Loading...', style: TextStyle(color: AppThemes.textPrimary)),
          error: (_, __) => const Text('Project Explorer', style: TextStyle(color: AppThemes.textPrimary)),
        ),
      ),
      body: projectsAsync.when(
        data: (projects) {
          final project = projects.firstWhere(
            (p) => p.id == id,
            orElse: () => projects.first,
          );
          return _buildBody(context, project);
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppThemes.accentBlue)),
        error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
      ),
    );
  }

  Widget _buildBody(BuildContext context, dynamic project) {
    return Column(
      children: [
        if (project.tasks.isNotEmpty) _buildTaskDashboard(project),
        Expanded(
          child: project.filePaths.isEmpty
              ? const Center(
                  child: Text('No files in this project', style: TextStyle(color: AppThemes.textSecondary)),
                )
              : _buildFileList(context, project),
        ),
      ],
    );
  }

  Widget _buildTaskDashboard(dynamic project) {
    final doneCount = project.tasks.where((t) => t.status.name == 'done').length;
    final totalCount = project.tasks.length;
    final progress = totalCount > 0 ? doneCount / totalCount : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppThemes.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppThemes.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Build Progress',
                style: TextStyle(color: AppThemes.textPrimary, fontWeight: FontWeight.bold),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(color: AppThemes.accentBlue, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppThemes.bgDark,
              color: AppThemes.accentBlue,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: project.tasks.map<Widget>((task) {
              final isDone = task.status.name == 'done';
              final isDoing = task.status.name == 'doing';
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDone 
                    ? Colors.green.withAlpha(20) 
                    : isDoing ? Colors.orange.withAlpha(20) : AppThemes.bgDark,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDone 
                      ? Colors.green.withAlpha(50) 
                      : isDoing ? Colors.orange.withAlpha(50) : AppThemes.dividerColor,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isDone ? Icons.check_circle : isDoing ? Icons.pending : Icons.circle_outlined,
                      size: 12,
                      color: isDone ? Colors.green : isDoing ? Colors.orange : AppThemes.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      task.title,
                      style: TextStyle(
                        color: isDone ? Colors.green : isDoing ? Colors.orange : AppThemes.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFileList(BuildContext context, dynamic project) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: project.filePaths.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: AppThemes.dividerColor),
      itemBuilder: (context, index) {
        final path = project.filePaths[index];
        final parts = path.split('/');
        final fileName = parts.last;
        final folderPath = parts.length > 1 ? path.substring(0, path.lastIndexOf('/')) : '';

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _getFileColor(fileName).withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_getFileIcon(fileName), color: _getFileColor(fileName), size: 20),
          ),
          title: Text(
            fileName,
            style: const TextStyle(color: AppThemes.textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
          ),
          subtitle: folderPath.isNotEmpty 
            ? Text(
                folderPath,
                style: const TextStyle(color: AppThemes.textSecondary, fontSize: 11),
              )
            : null,
          trailing: const Icon(Icons.chevron_right, color: AppThemes.textSecondary, size: 18),
          onTap: () {
            final encodedPath = Uri.encodeComponent(path);
            context.push('/home/projects/${project.id}/editor/$encodedPath');
          },
        );
      },
    );
  }

  IconData _getFileIcon(String fileName) {
    if (fileName.endsWith('.dart')) return Icons.code;
    if (fileName.endsWith('.js') || fileName.endsWith('.ts')) return Icons.javascript;
    if (fileName.endsWith('.html')) return Icons.html;
    if (fileName.endsWith('.css')) return Icons.css;
    if (fileName.endsWith('.md')) return Icons.description_outlined;
    if (fileName.endsWith('.json')) return Icons.settings_ethernet;
    return Icons.insert_drive_file_outlined;
  }

  Color _getFileColor(String fileName) {
    if (fileName.endsWith('.dart')) return Colors.blue;
    if (fileName.endsWith('.js') || fileName.endsWith('.ts')) return Colors.yellow;
    if (fileName.endsWith('.html')) return Colors.orange;
    if (fileName.endsWith('.css')) return Colors.blueAccent;
    if (fileName.endsWith('.md')) return Colors.teal;
    return AppThemes.textSecondary;
  }
}
