import 'dart:convert';
import 'dart:typed_data';
import '../../domain/models/chat_message.dart';
import '../../domain/models/agent_step.dart';
import '../../domain/interfaces/ai_provider.dart';
import 'agent_tool.dart';
import 'web_search_tool.dart';
import 'url_reader_tool.dart';
import 'build_project_tool.dart';
import 'call_external_tool.dart';
import 'evaluate_run_tool.dart';
import 'file_search_tool.dart';
import 'list_external_tools_tool.dart';
import 'list_benchmarks_tool.dart';
import 'terminal_tool.dart';
import 'read_file_tool.dart';
import 'edit_file_tool.dart';
import 'create_file_tool.dart';
import 'list_directory_tool.dart';
import 'install_package_tool.dart';
import 'list_projects_tool.dart';
import 'get_project_context_tool.dart';
import 'screenshot_tool.dart';
import 'git_tool.dart';
import 'analyzer_tool.dart';
import '../services/external_tool_service.dart';
import '../services/agent_eval_service.dart';
import '../services/agent_memory_service.dart';
import '../services/agent_permission_service.dart';
import '../services/agent_run_service.dart';
import '../storage/workspace_manager.dart';
import '../../domain/models/tool_audit_entry.dart';

// ── Mode-specific system prompts ──────────────────────────────────────────────
const _chatSystemPrompt =
    '''You are a helpful, conversational AI assistant built into NextGen IDE.
Answer questions directly and concisely. If the user asks you to build, create, or edit code files, ask them to switch to Agent or Code mode.
''';

// The AUTONOMOUS AGENT prompt — no waiting, no stopping, full loop until done.
const _agentSystemPrompt = '''
You are the world's most advanced, TOP 1 Elite Developer AI Agent natively built into NextGen IDE.
You are tasked with producing PERFECT, production-ready, beautiful, and bulletproof project builds. Your work must be flawless.

CRITICAL RULES YOU MUST FOLLOW:

1. DISCOVERY & CONTEXT:
   - ALWAYS explore before acting. Use `list_directory`, `read_file`, and `get_project_context` to understand the codebase.
   - Do not guess or hallucinate. Read the actual files.
   - Treat the current repository as the source of truth. Work with the existing architecture rather than inventing parallel systems.

2. REQUIREMENTS, DESIGN & AESTHETICS:
   - For UI/Frontend tasks: You MUST use premium, modern aesthetics (e.g., vibrant tailored colors, sleek dark modes, glassmorphism, responsive design, animations). 
   - DO NOT output plain, basic, or generic HTML/CSS. Build interfaces that will WOW the user at first glance. Make it feel premium.
   - For Backend/Logic tasks: Implement robust error handling, validation, secure patterns, and type safety.
   - NEVER use placeholders, "TODOs", or dummy implementations. Generate full, working, comprehensive code unconditionally.

3. EXECUTION PROTOCOL & TOOLS:
   - Respond using the structured JSON action protocol described below.
   - Before executing large changes, output an "# Implementation Plan" using normal markdown.
   - ALWAYS use `create_file` or `edit_file` to modify the codebase or `build_project` to bootstrap entirely new apps.
   - After making changes, run the strongest available verification command and inspect the result.
   - Do not stop until the user's request is 100% perfectly fulfilled.

4. TASK TRACKING:
   - For every sub-task you start, output exactly: "TASK_UPDATE: [ ] -> [/] Task Name"
   - When a task is finalized successfully, output exactly: "TASK_UPDATE: [/] -> [x] Task Name"
   - Do not output additional text on the same line. Keep tasks granular.

5. ENVIRONMENT STATUS (AgentBus):
   - **Terminal**: Run necessary terminal commands using `EVENT: terminalCommand | "your-command"`. Example command: `npm run dev &`
   - **Files**: Trigger file tree updates using `EVENT: fileRefreshRequested`
   - **Deployment**: Provide status updates using `EVENT: deployStatusUpdate | {"status": "success", "message": "Done!"}`.

6. DEFINITION OF DONE:
   - The implementation is only complete when the changed code is internally consistent, relevant files are updated, and verification has passed or a concrete environment limitation is identified.
   - If a command fails, read the error carefully, fix the root cause, and retry.
   - Never claim success based only on intentions or partial edits.

You are expected to operate flawlessly. A failure to build beautiful, working, complete projects is UNACCEPTABLE.
''';

const _codeSystemPrompt = '''
You are an expert engineer.
1. NEVER output code blocks in chat. Use create_file/edit_file.
2. Update task progress: "TASK_UPDATE: [ ] -> [/] Task" or "TASK_UPDATE: [/] -> [x] Task".
3. Use find_in_files or list_directory to explore before editing.
''';

const _deepThinkSystemPrompt =
    '''You are an expert analytical assistant that thinks deeply before answering.

Approach every question by:
1. Breaking it down into components
2. Considering multiple perspectives and approaches
3. Identifying assumptions and potential flaws
4. Reasoning step by step, showing your work
5. Arriving at a well-justified conclusion

Use markdown headers and bullet points to structure your reasoning clearly.
Be thorough — the user wants depth, not speed.
''';

const _webSystemPrompt =
    '''You are a web research assistant with real-time internet access.

ALWAYS start by searching the web for current information before answering.
Use a structured action with the `web_search` tool.

Then if you need more details, read specific pages:
Use a structured action with the `read_url` tool.

Synthesize multiple sources into a comprehensive, well-cited answer.
Always mention your sources.
''';

// ── AgentService ──────────────────────────────────────────────────────────────
class AgentService {
  final AIProvider provider;
  final String mode;
  final int maxToolCalls;

  final List<AgentTool> _tools;
  final ExternalToolService _externalToolService;
  final AgentRunService _agentRunService;
  final AgentEvalService _agentEvalService;
  final AgentMemoryService _agentMemoryService;
  final AgentPermissionService _agentPermissionService;
  final String? _activeProjectPath;
  final String? Function()? _projectPathProvider;

  AgentService({
    required this.provider,
    required WorkspaceManager workspaceManager,
    this.mode = 'Agent',
    String? activeProjectPath,
    String? Function()? projectPathProvider,
    int? maxToolCalls,
    AgentMemoryService? memoryService,
    AgentPermissionService? permissionService,
  }) : maxToolCalls = maxToolCalls ?? (mode == 'Chat' ? 0 : 30),
       _agentPermissionService = permissionService ?? AgentPermissionService(),
       _externalToolService = ExternalToolService(
         permissionService: permissionService ?? AgentPermissionService(),
       ),
       _agentRunService = AgentRunService(),
       _agentEvalService = AgentEvalService(),
       _agentMemoryService = memoryService ?? AgentMemoryService(),
       _activeProjectPath = activeProjectPath,
       _projectPathProvider = projectPathProvider,
       _tools = [
         WebSearchTool(),
         UrlReaderTool(),
         BuildProjectTool(workspaceManager),
         FileSearchTool(workspaceManager),
         TerminalTool(
           activeProjectPath: activeProjectPath,
           projectPathProvider: projectPathProvider,
         ),
         ReadFileTool(workspaceManager),
         EditFileTool(workspaceManager),
         CreateFileTool(workspaceManager),
         ListDirectoryTool(workspaceManager),
         InstallPackageTool(),
         ListProjectsTool(),
         GetProjectContextTool(),
         ScreenshotTool(),
         GitTool(
           activeProjectPath: activeProjectPath,
           projectPathProvider: projectPathProvider,
         ),
         AnalyzerTool(),
         ListBenchmarksTool(),
         EvaluateRunTool(
           runService: _agentRunService,
           evalService: _agentEvalService,
         ),
         ListExternalToolsTool(_externalToolService),
         CallExternalTool(_externalToolService),
       ];

  String _systemPrompt() {
    String basePrompt;
    switch (mode) {
      case 'Chat':
        basePrompt = _chatSystemPrompt;
        break;
      case 'Code':
        basePrompt = _codeSystemPrompt;
        break;
      case 'Deep Think':
        basePrompt = _deepThinkSystemPrompt;
        break;
      case 'Web':
        basePrompt = _webSystemPrompt;
        break;
      case 'Agent':
      default:
        basePrompt = _agentSystemPrompt;
        break;
    }

    if (mode == 'Chat') return basePrompt;

    // Append strict tool calling rules and definitions
    return '''$basePrompt

=== STRUCTURED ACTION PROTOCOL ===
You must respond with EXACTLY ONE valid JSON object.
Do not wrap it in markdown fences.
Do not use XML tags.

Schema:
{
  "assistant_message": "string",
  "final": true|false,
  "actions": [
    {
      "type": "tool",
      "name": "tool_name",
      "args": {"key":"value"}
    },
    {
      "type": "event",
      "event": "eventName",
      "payload": "string or JSON value"
    }
  ]
}

Rules:
- Put user-facing prose in `assistant_message`.
- Put machine actions in `actions`.
- Set `final` to true only when you are done and do not need more tool results.
- You may return multiple actions in one response only when they are independent and safe to parallelize.
- Never invent tools or parameters.
- Every tool call may include an `environment` field. Default to `workspace`. Allowed values depend on the tool.
- Destructive actions MUST include `"confirm": true` and a non-empty `"confirmation_reason"` argument.
- External tool calls MUST include `"credential_scope"` so credentials stay scoped and auditable.

Available Tools (use exact parameter names):
- {"name": "web_search", "query": "string"}
- {"name": "read_url", "url": "string"}
- {"name": "build_project", "name": "string", "id": "string", "description": "string", "files": [{"path": "string", "content": "string"}], "tasks": [{"id": "string", "title": "string", "status": "todo|inProgress|done"}]}
- {"name": "search_files", "query": "string", "project_id": "string (optional)", "max_results": number (optional)}
- {"name": "run_terminal_command", "command": "string"}
- {"name": "read_file", "path": "string"}
- {"name": "edit_file", "path": "string", "target_text": "string (set to OVERWRITE for full replacement)", "replacement_text": "string"}
- {"name": "create_file", "path": "string", "content": "string"}
- {"name": "list_directory", "path": "string"}
- {"name": "install_package", "package": "string", "manager": "npm|flutter|pip"}
- {"name": "list_projects"}
- {"name": "get_project_context", "id": "string"}
- {"name": "take_screenshot"}
- {"name": "git", "command": "status|commit|push", "args": ["string"]}
- {"name": "dart_analyzer", "file_path": "string (optional)"}
- {"name": "list_benchmarks"}
- {"name": "evaluate_run", "run_id": "string", "project_path": "string (optional)"}
- {"name": "list_external_tools"}
- {"name": "call_external_tool", "tool_id": "string", "action": "string (optional)", "payload": {"any":"json"}}
''';
  }

  /// Main agent loop — yields AgentStep events for the UI to display
  Stream<AgentStep> run(List<ChatMessage> history) async* {
    String latestUserMessage = '';
    for (final message in history.reversed) {
      if (message.role == MessageRole.user && message.content.trim().isNotEmpty) {
        latestUserMessage = message.content;
        break;
      }
    }
    final resolvedProjectPath = _activeProjectPath ?? _projectPathProvider?.call();
    final memoryContext = await _agentMemoryService.buildExecutionContext(
      task: latestUserMessage,
      projectPath: resolvedProjectPath,
      agentName: mode,
    );

    // Build conversation with system prompt injected
    final messages = [
      ChatMessage(role: MessageRole.system, content: _systemPrompt()),
      if (memoryContext.trim().isNotEmpty)
        ChatMessage(role: MessageRole.system, content: memoryContext),
      ...history,
    ];

    int toolCallCount = 0;
    bool continueLoop = true;

    while (continueLoop && toolCallCount <= maxToolCalls) {
      final rawResponse = await provider.generate(messages);
      final envelope = _parseStructuredEnvelope(rawResponse);

      if (envelope == null) {
        final repairInstruction = ChatMessage(
          role: MessageRole.user,
          content:
              'SYSTEM ERROR: Your last response was not valid structured JSON. Respond with exactly one JSON object following the declared schema.',
        );
        messages.add(ChatMessage(role: MessageRole.model, content: rawResponse));
        messages.add(repairInstruction);
        yield AgentStep(
          type: AgentStepType.toolResult,
          content:
              'Invalid structured response. The model has been asked to retry with valid JSON.',
          toolName: 'schema_error',
        );
        toolCallCount++;
        continue;
      }

      messages.add(ChatMessage(role: MessageRole.model, content: rawResponse));

      if (envelope.assistantMessage.trim().isNotEmpty) {
        yield* _emitAssistantMarkers(envelope.assistantMessage);
      }

      if (envelope.actions.isEmpty) {
        continueLoop = !envelope.isFinal;
        if (envelope.isFinal) break;
        continue;
      }

      final toolActions = envelope.actions
          .where((action) => action.type == 'tool')
          .toList();
      final eventActions = envelope.actions
          .where((action) => action.type == 'event')
          .toList();

      for (final eventAction in eventActions) {
        final eventName = eventAction.eventName ?? '';
        final payload = eventAction.payload;
        yield AgentStep(
          type: AgentStepType.busEvent,
          content: '$eventName: ${payload ?? ''}',
          toolName: eventName,
          toolParams: {'payload': payload},
        );
      }

      final validationError = _validateActions(toolActions);
      if (validationError != null) {
        messages.add(
          ChatMessage(
            role: MessageRole.user,
            content:
                'SYSTEM ERROR: $validationError. Re-emit the full JSON response with corrected actions.',
          ),
        );
        yield AgentStep(
          type: AgentStepType.toolResult,
          content: validationError,
          toolName: 'schema_error',
        );
        toolCallCount++;
        continue;
      }

      if (toolActions.isEmpty) {
        continueLoop = !envelope.isFinal;
        if (envelope.isFinal) break;
        continue;
      }

      final executedResults = await _executeToolActions(toolActions);

      for (final executed in executedResults) {
        yield AgentStep(
          type: AgentStepType.toolCall,
          content: _describeToolCall(executed.toolName, executed.params),
          toolName: executed.toolName,
          toolParams: executed.params,
        );

        final displayResult =
            executed.toolName == 'take_screenshot' &&
                !executed.result.startsWith('Error')
            ? '[Screenshot captured natively]'
            : executed.result;

        yield AgentStep(
          type: AgentStepType.toolResult,
          content: displayResult,
          toolName: executed.toolName,
          toolParams: executed.params,
        );
      }

      final resultPayload = <Map<String, dynamic>>[];
      final images = <Uint8List>[];

      for (final executed in executedResults) {
        var resultText = executed.result;
        if (executed.toolName == 'take_screenshot' &&
            !executed.result.startsWith('Error')) {
          try {
            images.add(base64Decode(executed.result));
            resultText =
                'Screenshot captured successfully and attached as an image.';
          } catch (e) {
            resultText = 'Failed to decode screenshot: $e';
          }
        }

        resultPayload.add({
          'tool': executed.toolName,
          'args': executed.params,
          'result': resultText,
        });
      }

      messages.add(
        ChatMessage(
          role: MessageRole.user,
          content:
              'ACTION_RESULTS:\n${jsonEncode(resultPayload)}\n\nContinue with the next structured JSON response.',
          images: images.isEmpty ? null : images,
        ),
      );
      toolCallCount += toolActions.length;
      continueLoop = !envelope.isFinal;
    }

    if (toolCallCount > maxToolCalls) {
      yield const AgentStep(
        type: AgentStepType.text,
        content: '\n\n*(Reached maximum tool call limit)*',
      );
    }
  }

  Stream<AgentStep> _emitAssistantMarkers(String text) async* {
    const taskMarker = 'TASK_UPDATE:';
    const eventMarker = 'EVENT:';
    final markerBlockRegex = RegExp(
      r'(TASK_UPDATE:\s*.+?|EVENT:\s*[a-zA-Z0-9_-]+\s*\|?\s*.*?)(\n|(?=TASK_UPDATE:)|(?=EVENT:)|$)',
      multiLine: true,
      dotAll: true,
    );

    var buffer = text;
    while (true) {
      final match = markerBlockRegex.firstMatch(buffer);
      if (match == null) break;

      final preText = buffer.substring(0, match.start);
      if (preText.trim().isNotEmpty) {
        yield AgentStep(type: AgentStepType.text, content: preText);
      }

      final matchContent = match.group(1) ?? '';
      if (matchContent.startsWith(taskMarker)) {
        yield AgentStep(
          type: AgentStepType.taskUpdate,
          content: matchContent.replaceFirst(taskMarker, '').trim(),
        );
      } else if (matchContent.startsWith(eventMarker)) {
        final content = matchContent.replaceFirst(eventMarker, '').trim();
        final parts = content.split('|');
        final type = parts[0].trim();
        final payload = parts.length > 1 ? parts.sublist(1).join('|').trim() : '';
        yield AgentStep(
          type: AgentStepType.busEvent,
          content: '$type: $payload',
          toolName: type,
          toolParams: {'payload': payload},
        );
      }

      buffer = buffer.substring(match.end);
    }

    if (buffer.trim().isNotEmpty) {
      yield AgentStep(type: AgentStepType.text, content: buffer);
    }
  }

  _StructuredEnvelope? _parseStructuredEnvelope(String rawResponse) {
    try {
      final cleaned = rawResponse
          .replaceAll(RegExp(r'^```json\s*'), '')
          .replaceAll(RegExp(r'^```\s*'), '')
          .replaceAll(RegExp(r'\s*```$'), '')
          .trim();
      final decoded = jsonDecode(cleaned);
      if (decoded is! Map<String, dynamic>) return null;
      return _StructuredEnvelope.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  String? _validateActions(List<_StructuredAction> actions) {
    for (final action in actions) {
      if ((action.name ?? '').isEmpty) {
        return 'Tool action missing required "name"';
      }
      if (action.args == null) {
        return 'Tool action "${action.name}" missing required "args" object';
      }
      final toolExists = _tools.any((tool) => tool.name == action.name);
      if (!toolExists) {
        return 'Unknown tool "${action.name}"';
      }
      final decision = _agentPermissionService.evaluate(
        toolName: action.name!,
        params: Map<String, dynamic>.from(action.args ?? const {}),
      );
      if (!decision.allowed) {
        return decision.reason;
      }
    }
    return null;
  }

  Future<List<_ExecutedToolAction>> _executeToolActions(
    List<_StructuredAction> actions,
  ) async {
    if (_canRunInParallel(actions)) {
      return Future.wait(actions.map(_executeSingleToolAction));
    }
    final results = <_ExecutedToolAction>[];
    for (final action in actions) {
      results.add(await _executeSingleToolAction(action));
    }
    return results;
  }

  bool _canRunInParallel(List<_StructuredAction> actions) {
    const safeParallelTools = {
      'read_file',
      'list_directory',
      'web_search',
      'read_url',
      'search_files',
      'list_projects',
      'get_project_context',
      'list_benchmarks',
      'list_external_tools',
    };
    return actions.length > 1 &&
        actions.every((action) => safeParallelTools.contains(action.name));
  }

  Future<_ExecutedToolAction> _executeSingleToolAction(
    _StructuredAction action,
  ) async {
    final toolName = action.name ?? '';
    final params = Map<String, dynamic>.from(action.args ?? const {});
    final tool = _tools.firstWhere(
      (t) => t.name == toolName,
      orElse: () => _UnknownTool(toolName),
    );

    String result;
    final decision = _agentPermissionService.evaluate(
      toolName: toolName,
      params: params,
    );
    try {
      if (!decision.allowed) {
        result = 'Permission denied: ${decision.reason}';
      } else {
        result = await tool.execute(params);
      }
    } catch (e) {
      result = 'Tool error: $e';
    }

    await _agentPermissionService.recordAudit(
      ToolAuditEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        toolName: toolName,
        approvalMode: decision.approvalMode,
        environment: decision.environment,
        allowed: decision.allowed,
        requiresConfirmation: decision.requiresConfirmation,
        reason: decision.reason,
        params: params,
        resultSummary: result.length > 400 ? result.substring(0, 400) : result,
        createdAt: DateTime.now(),
      ),
    );

    return _ExecutedToolAction(
      toolName: toolName,
      params: params,
      result: result,
    );
  }

  String _describeToolCall(String toolName, Map<String, dynamic> params) {
    switch (toolName) {
      case 'web_search':
        return 'Searching: ${params['query'] ?? '...'}';
      case 'read_url':
        return 'Reading: ${params['url'] ?? '...'}';
      case 'build_project':
        final fileCount = (params['files'] as List?)?.length ?? 0;
        return 'Building "${params['name']}" ($fileCount files)';
      case 'search_files':
        return 'Searching files for "${params['query'] ?? '...'}"';
      case 'create_file':
        return params['path'] as String? ?? 'unknown';
      case 'edit_file':
        return params['path'] as String? ?? 'unknown';
      case 'read_file':
        return params['path'] as String? ?? 'unknown';
      case 'list_directory':
        return params['path'] as String? ?? '.';
      case 'install_package':
        final pkg = params['package'] ?? 'package';
        final mgr = params['manager'] ?? 'npm';
        return '$mgr install $pkg';
      case 'run_terminal_command':
        return params['command'] as String? ?? 'Running command...';
      case 'git':
        return 'git ${params['command'] ?? 'status'}';
      case 'dart_analyzer':
        return '${params['command'] ?? 'analyze'} ${params['file_path'] ?? params['project_name'] ?? '.'}';
      case 'list_benchmarks':
        return 'Listing benchmark tasks...';
      case 'evaluate_run':
        return 'Evaluating run ${params['run_id'] ?? 'unknown'}';
      case 'list_external_tools':
        return 'Listing external tools...';
      case 'call_external_tool':
        return 'Calling external tool ${params['tool_id'] ?? 'unknown'}';
      case 'take_screenshot':
        return 'Capturing device screenshot...';
      default:
        final p = Map<String, dynamic>.from(params)..remove('content');
        return '$toolName: ${p.isNotEmpty ? jsonEncode(p) : ''}';
    }
  }
}

class _StructuredEnvelope {
  final String assistantMessage;
  final bool isFinal;
  final List<_StructuredAction> actions;

  const _StructuredEnvelope({
    required this.assistantMessage,
    required this.isFinal,
    required this.actions,
  });

  factory _StructuredEnvelope.fromJson(Map<String, dynamic> json) {
    final rawActions = (json['actions'] as List?) ?? const [];
    return _StructuredEnvelope(
      assistantMessage: json['assistant_message'] as String? ?? '',
      isFinal: json['final'] as bool? ?? false,
      actions: rawActions
          .whereType<Map>()
          .map((action) => _StructuredAction.fromJson(Map<String, dynamic>.from(action)))
          .toList(),
    );
  }
}

class _StructuredAction {
  final String type;
  final String? name;
  final Map<String, dynamic>? args;
  final String? eventName;
  final dynamic payload;

  const _StructuredAction({
    required this.type,
    this.name,
    this.args,
    this.eventName,
    this.payload,
  });

  factory _StructuredAction.fromJson(Map<String, dynamic> json) {
    return _StructuredAction(
      type: json['type'] as String? ?? '',
      name: json['name'] as String?,
      args: json['args'] is Map
          ? Map<String, dynamic>.from(json['args'] as Map)
          : null,
      eventName: json['event'] as String?,
      payload: json['payload'],
    );
  }
}

class _ExecutedToolAction {
  final String toolName;
  final Map<String, dynamic> params;
  final String result;

  const _ExecutedToolAction({
    required this.toolName,
    required this.params,
    required this.result,
  });
}

/// Fallback for unknown tool names
class _UnknownTool implements AgentTool {
  final String _name;
  const _UnknownTool(this._name);

  @override
  String get name => _name;
  @override
  String get displayName => 'Unknown';
  @override
  String get uiIcon => 'help';
  @override
  String get description => '';

  @override
  Future<String> execute(Map<String, dynamic> params) async =>
      'Unknown tool: $_name';
}
