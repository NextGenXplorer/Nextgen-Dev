class AgentMemory {
  final String id;
  final String category;
  final String content;
  final String? projectPath;
  final String? agentName;
  final String? fingerprint;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;

  const AgentMemory({
    required this.id,
    required this.category,
    required this.content,
    this.projectPath,
    this.agentName,
    this.fingerprint,
    required this.createdAt,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'content': content,
        'projectPath': projectPath,
        'agentName': agentName,
        'fingerprint': fingerprint,
        'createdAt': createdAt.toIso8601String(),
        'metadata': metadata,
      };

  factory AgentMemory.fromJson(Map<String, dynamic> json) {
    return AgentMemory(
      id: json['id']?.toString() ?? '',
      category: json['category']?.toString() ?? 'general',
      content: json['content']?.toString() ?? '',
      projectPath: json['projectPath']?.toString(),
      agentName: json['agentName']?.toString(),
      fingerprint: json['fingerprint']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      metadata: json['metadata'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['metadata'] as Map<String, dynamic>)
          : const {},
    );
  }
}
