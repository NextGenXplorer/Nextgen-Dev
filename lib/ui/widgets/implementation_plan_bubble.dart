import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../themes.dart';

class ImplementationPlanBubble extends StatelessWidget {
  const ImplementationPlanBubble({
    super.key,
    required this.content,
    required this.onProceed,
    required this.onEdit,
  });

  final String content;
  final VoidCallback onProceed;
  final VoidCallback onEdit;

  List<Map<String, dynamic>> _parseTasks() {
    final List<Map<String, dynamic>> tasks = [];
    final lines = content.split('\n');
    bool inTaskSection = false;

    for (var line in lines) {
      if (line.toLowerCase().contains('## tasks') ||
          line.toLowerCase().contains('# tasks')) {
        inTaskSection = true;
        continue;
      }
      if (inTaskSection &&
          (line.startsWith('#') || line.trim().isEmpty) &&
          tasks.isNotEmpty) {
        // Break out if we hit another header after tasks
        if (line.startsWith('##') || line.startsWith('#')) break;
      }

      if (inTaskSection) {
        final taskMatch = RegExp(r'-\s+\[([ xX])\]\s+(.+)').firstMatch(line);
        if (taskMatch != null) {
          final isDone = taskMatch.group(1) != ' ';
          final title = taskMatch.group(2)!.trim();
          tasks.add({'title': title, 'isDone': isDone});
        } else if (line.trim().startsWith('- ')) {
          // Fallback for simple bullet points in task section
          final title = line.trim().substring(2).trim();
          if (title.isNotEmpty) {
            tasks.add({'title': title, 'isDone': false});
          }
        }
      }
    }
    return tasks;
  }

  @override
  Widget build(BuildContext context) {
    final tasks = _parseTasks();
    final cleanContent = content
        .replaceAll(RegExp(r'## Tasks[\s\S]*?(?=#|$)'), '')
        .replaceAll('# Implementation Plan', '')
        .trim();

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppThemes.surfaceDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppThemes.accentCyan.withAlpha(50),
          width: 1.5,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppThemes.surfaceCard, AppThemes.surfaceDark],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(40),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: AppThemes.accentCyan.withAlpha(20),
            blurRadius: 25,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.architecture_outlined,
                color: AppThemes.accentCyan,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Implementation Plan',
                style: TextStyle(
                  color: AppThemes.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withAlpha(100)),
                ),
                child: const Text(
                  'Pending Approval',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppThemes.dividerColor),
          const SizedBox(height: 12),
          MarkdownBody(
            data: cleanContent,
            selectable: true,
            styleSheet: MarkdownStyleSheet(
              p: const TextStyle(
                color: AppThemes.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
              h2: const TextStyle(
                color: AppThemes.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              h3: const TextStyle(
                color: AppThemes.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              listBullet: const TextStyle(color: AppThemes.accentCyan),
            ),
          ),
          if (tasks.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Tasks',
              style: TextStyle(
                color: AppThemes.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...tasks.map(
              (task) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      task['isDone']
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                      size: 16,
                      color: task['isDone']
                          ? Colors.green
                          : AppThemes.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        task['title'],
                        style: TextStyle(
                          color: task['isDone']
                              ? AppThemes.textSecondary
                              : AppThemes.textPrimary,
                          fontSize: 13,
                          decoration: task['isDone']
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(
                    Icons.edit_note,
                    color: AppThemes.accentCyan,
                  ),
                  label: const Text(
                    'Edit',
                    style: TextStyle(
                      color: AppThemes.accentCyan,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(
                      color: AppThemes.accentCyan.withAlpha(100),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onProceed,
                  icon: const Icon(Icons.rocket_launch, color: Colors.white),
                  label: const Text(
                    'Proceed',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: AppThemes.accentCyan,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
