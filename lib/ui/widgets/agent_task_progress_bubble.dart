import 'package:flutter/material.dart';

class AgentTaskProgressBubble extends StatelessWidget {
  final List<AgentTask> tasks;

  const AgentTaskProgressBubble({super.key, required this.tasks});

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
                Icon(Icons.list_alt, size: 18, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Task Progress',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ...tasks.map((task) => Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                _buildStatusIcon(context, task.status),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    task.title,
                    style: TextStyle(
                      color: task.status == TaskStatus.pending 
                        ? Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6)
                        : Theme.of(context).colorScheme.onSurface,
                      decoration: task.status == TaskStatus.completed 
                        ? TextDecoration.lineThrough 
                        : null,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(BuildContext context, TaskStatus status) {
    switch (status) {
      case TaskStatus.completed:
        return Icon(Icons.check_circle, size: 18, color: Colors.green.shade400);
      case TaskStatus.inProgress:
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case TaskStatus.pending:
        return Icon(Icons.circle_outlined, size: 18, color: Theme.of(context).colorScheme.outline);
    }
  }
}

enum TaskStatus { pending, inProgress, completed }

class AgentTask {
  final String title;
  final TaskStatus status;

  AgentTask({required this.title, required this.status});
}
