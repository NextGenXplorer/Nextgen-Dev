import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../infrastructure/services/project_service.dart';
import '../../domain/models/project.dart';
import '../themes.dart';
import '../widgets/app_drawer.dart';

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(projectListProvider);

    return Scaffold(
      backgroundColor: AppThemes.bgDark,
      drawer: const AppDrawer(currentConversationId: null),
      appBar: AppBar(
        backgroundColor: AppThemes.bgDark,
        elevation: 0,
        title: const Text(
          'Projects',
          style: TextStyle(
            color: AppThemes.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppThemes.textPrimary),
            onPressed: () => ref.invalidate(projectListProvider),
          ),
        ],
      ),
      body: projectsAsync.when(
        data: (projects) =>
            projects.isEmpty ? _buildEmptyState() : _buildProjectList(projects),
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppThemes.accentCyan),
        ),
        error: (err, stack) => Center(
          child: Text('Error: $err', style: const TextStyle(color: Colors.red)),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open_outlined,
            size: 80,
            color: AppThemes.textSecondary.withAlpha(50),
          ),
          const SizedBox(height: 16),
          const Text(
            'No projects yet',
            style: TextStyle(
              color: AppThemes.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Switch to Agent mode and ask it to build something for you!',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppThemes.textSecondary, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectList(List<Project> projects) {
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(projectListProvider),
      color: AppThemes.accentCyan,
      backgroundColor: AppThemes.surfaceDark,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: projects.length,
        itemBuilder: (context, index) {
          final project = projects[index];
          return _buildProjectCard(project);
        },
      ),
    );
  }

  Widget _buildProjectCard(Project project) {
    final dateStr = DateFormat('MMM dd, yyyy HH:mm').format(project.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppThemes.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppThemes.dividerColor, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => context.push('/home/projects/${project.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppThemes.accentCyan.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppThemes.accentCyan.withAlpha(50),
                    width: 0.5,
                  ),
                ),
                child: const Icon(
                  Icons.code,
                  color: AppThemes.accentCyan,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.name,
                      style: const TextStyle(
                        color: AppThemes.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      project.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppThemes.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          color: AppThemes.textSecondary,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          dateStr,
                          style: const TextStyle(
                            color: AppThemes.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.insert_drive_file_outlined,
                          color: AppThemes.textSecondary,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${project.filePaths.length} files',
                          style: const TextStyle(
                            color: AppThemes.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: AppThemes.textSecondary,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProjectDetailScreen extends ConsumerWidget {
  final String id;
  const ProjectDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // This will be replaced by a more complex file explorer later.
    return Scaffold(
      backgroundColor: AppThemes.bgDark,
      appBar: AppBar(
        backgroundColor: AppThemes.bgDark,
        title: Text(
          'Project $id',
          style: const TextStyle(color: AppThemes.textPrimary),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.construction,
              size: 60,
              color: AppThemes.accentCyan,
            ),
            const SizedBox(height: 16),
            Text(
              'Explorer for $id coming soon...',
              style: const TextStyle(color: AppThemes.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppThemes.accentCyan.withAlpha(20),
                foregroundColor: AppThemes.accentCyan,
                side: BorderSide(
                  color: AppThemes.accentCyan.withAlpha(50),
                  width: 1,
                ),
              ),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}
