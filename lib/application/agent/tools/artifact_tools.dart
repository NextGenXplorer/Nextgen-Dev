import 'dart:convert';
import 'dart:io';
import '../../../domain/agent/agent_tool.dart';

/// Models an artifact created by the agent for rich UI rendering
class AgentArtifact {
  final String id;
  final String title;
  final String type; // 'markdown', 'mermaid', 'code_plan'
  final String filePath;
  final DateTime createdAt;

  AgentArtifact({
    required this.id,
    required this.title,
    required this.type,
    required this.filePath,
    required this.createdAt,
  });
}

/// Service that persists artifacts to disk and notifies the UI
abstract class ArtifactUIService {
  Future<String> saveAndRenderArtifact(AgentArtifact artifact, String content);
}

class CreateArtifactTool implements AgentTool {
  final ArtifactUIService artifactService;
  final String projectScopePath; // e.g., /data/user/0/.../app_flutter/artifacts/

  CreateArtifactTool({
    required this.artifactService,
    required this.projectScopePath,
  });

  @override
  String get name => 'create_artifact';

  @override
  String get description => 
      'Creates a rich markdown document, implementation plan, or mermaid '
      'diagram to present structured data to the user. Do this instead of '
      'writing huge blocks of code in the chat. The artifact is saved and '
      'immediately rendered in a split-screen for the user to review.';

  @override
  Map<String, dynamic> get parameters => {
    'type': 'object',
    'properties': {
      'title': {
        'type': 'string',
        'description': 'A human-readable title for the artifact (e.g., "Authentication Plan").',
      },
      'type': {
        'type': 'string',
        'enum': ['markdown', 'mermaid', 'code_plan'],
        'description': 'The type of content being generated.',
      },
      'content': {
        'type': 'string',
        'description': 'The complete string content of the artifact.',
      }
    },
    'required': ['title', 'type', 'content'],
  };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final title = arguments['title'] as String;
    final type = arguments['type'] as String;
    final content = arguments['content'] as String;

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final ext = type == 'mermaid' ? 'mermaid' : 'md';
    final fileName = '${title.replaceAll(' ', '_').toLowerCase()}_$id.$ext';
    final filePath = '$projectScopePath/$fileName';

    final artifact = AgentArtifact(
      id: id,
      title: title,
      type: type,
      filePath: filePath,
      createdAt: DateTime.now(),
    );

    try {
      // Hands off the content to the UI service which writes it to disk and triggers Riverpod UI update
      await artifactService.saveAndRenderArtifact(artifact, content);
      return 'Successfully created and rendered artifact "$title". The user is now looking at it.';
    } catch (e) {
      return 'Failed to create artifact: $e';
    }
  }
}
