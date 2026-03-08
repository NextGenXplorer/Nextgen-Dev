enum TaskStatus { todo, doing, done }

class ProjectTask {
  final String id;
  final String title;
  final TaskStatus status;

  const ProjectTask({
    required this.id,
    required this.title,
    this.status = TaskStatus.todo,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'status': status.name,
      };

  factory ProjectTask.fromJson(Map<String, dynamic> json) => ProjectTask(
        id: json['id'] as String,
        title: json['title'] as String,
        status: TaskStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => TaskStatus.todo,
        ),
      );
}

class Project {
  final String id;
  final String name;
  final String description;
  final DateTime createdAt;
  final List<String> filePaths;
  final List<ProjectTask> tasks;

  const Project({
    required this.id,
    required this.name,
    required this.description,
    required this.createdAt,
    this.filePaths = const [],
    this.tasks = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'createdAt': createdAt.toIso8601String(),
        'filePaths': filePaths,
        'tasks': tasks.map((e) => e.toJson()).toList(),
      };

  factory Project.fromJson(Map<String, dynamic> json) => Project(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        filePaths: (json['filePaths'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
        tasks: (json['tasks'] as List<dynamic>?)?.map((e) => ProjectTask.fromJson(e)).toList() ?? [],
      );
}

