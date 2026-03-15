import 'dart:convert';
import 'dart:typed_data';
import '../../domain/models/chat_message.dart';
import '../../domain/models/agent_step.dart';
import '../../domain/interfaces/ai_provider.dart';
import 'agent_tool.dart';
import 'web_search_tool.dart';
import 'url_reader_tool.dart';
import 'build_project_tool.dart';
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
import '../storage/workspace_manager.dart';

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

2. REQUIREMENTS, DESIGN & AESTHETICS:
   - For UI/Frontend tasks: You MUST use premium, modern aesthetics (e.g., vibrant tailored colors, sleek dark modes, glassmorphism, responsive design, animations). 
   - DO NOT output plain, basic, or generic HTML/CSS. Build interfaces that will WOW the user at first glance. Make it feel premium.
   - For Backend/Logic tasks: Implement robust error handling, validation, secure patterns, and type safety.
   - NEVER use placeholders, "TODOs", or dummy implementations. Generate full, working, comprehensive code unconditionally.

3. EXECUTION PROTOCOL & TOOLS:
   - Output ONE tool call per response wrapped in `<tool_call>{...}</tool_call>`.
   - Never output markdown code blocks wrapped around the `<tool_call>` tags. Just pure `<tool_call>`.
   - Before executing large changes, output an "# Implementation Plan" using normal markdown.
   - ALWAYS use `create_file` or `edit_file` to modify the codebase or `build_project` to bootstrap entirely new apps.
   - Do not stop until the user's request is 100% perfectly fulfilled. 

4. TASK TRACKING:
   - For every sub-task you start, output exactly: "TASK_UPDATE: [ ] -> [/] Task Name"
   - When a task is finalized successfully, output exactly: "TASK_UPDATE: [/] -> [x] Task Name"
   - Do not output additional text on the same line. Keep tasks granular.

5. ENVIRONMENT STATUS (AgentBus):
   - **Terminal**: Run necessary terminal commands using `EVENT: terminalCommand | "your-command"`. Example command: `npm run dev &`
   - **Files**: Trigger file tree updates using `EVENT: fileRefreshRequested`
   - **Deployment**: Provide status updates using `EVENT: deployStatusUpdate | {"status": "success", "message": "Done!"}`.

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
<tool_call>{"name": "web_search", "query": "..."}</tool_call>

Then if you need more details, read specific pages:
<tool_call>{"name": "read_url", "url": "..."}</tool_call>

Synthesize multiple sources into a comprehensive, well-cited answer.
Always mention your sources.
''';

// ── Tool call regex ───────────────────────────────────────────────────────────
final _toolCallRegex = RegExp(r'<tool_call>(.*?)</tool_call>', dotAll: true);

// ── AgentService ──────────────────────────────────────────────────────────────
class AgentService {
  final AIProvider provider;
  final String mode;
  final int maxToolCalls;

  final List<AgentTool> _tools;

  AgentService({
    required this.provider,
    required WorkspaceManager workspaceManager,
    this.mode = 'Agent',
    String? activeProjectPath,
    int? maxToolCalls,
  }) : maxToolCalls = maxToolCalls ?? (mode == 'Chat' ? 0 : 30),
       _tools = [
         WebSearchTool(),
         UrlReaderTool(),
         BuildProjectTool(workspaceManager),
         TerminalTool(activeProjectPath: activeProjectPath),
         ReadFileTool(workspaceManager),
         EditFileTool(workspaceManager),
         CreateFileTool(workspaceManager),
         ListDirectoryTool(workspaceManager),
         InstallPackageTool(),
         ListProjectsTool(),
         GetProjectContextTool(),
         ScreenshotTool(),
         GitTool(),
         AnalyzerTool(),
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

=== TOOL USAGE INSTRUCTIONS ===
You have access to a set of specialized tools. 
To use a tool, you MUST output a single JSON block wrapped inside <tool_call> and </tool_call> tags.
ONLY ONE tool call per response. NEVER invent tools or guess the parameters.

Example of a correct tool call:
<tool_call>
{
  "name": "create_file",
  "path": "portfolio/index.html",
  "content": "<!DOCTYPE html>..."
}
</tool_call>

Available Tools (use exact parameter names):
- {"name": "web_search", "query": "string"}
- {"name": "read_url", "url": "string"}
- {"name": "build_project", "name": "string", "id": "string", "description": "string", "files": [{"path": "string", "content": "string"}], "tasks": [{"id": "string", "title": "string", "status": "todo|inProgress|done"}]}
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
''';
  }

  /// Main agent loop — yields AgentStep events for the UI to display
  Stream<AgentStep> run(List<ChatMessage> history) async* {
    // Build conversation with system prompt injected
    final messages = [
      ChatMessage(role: MessageRole.system, content: _systemPrompt()),
      ...history,
    ];

    int toolCallCount = 0;
    bool continueLoop = true;

    while (continueLoop && toolCallCount <= maxToolCalls) {
      String accumulated = '';

      String streamBuffer = '';

      // Markers we want to intercept
      const taskMarker = 'TASK_UPDATE:';
      const eventMarker = 'EVENT:';

      // Regex that catches the full block of a marker.
      // It captures the marker and everything until a newline or another marker start.
      final markerBlockRegex = RegExp(
        r'(TASK_UPDATE:\s*.+?|EVENT:\s*[a-zA-Z0-9_-]+\s*\|?\s*.*?)(\n|(?=TASK_UPDATE:)|(?=EVENT:)|(?=<tool_call>)|$)',
        multiLine: true,
        dotAll: true,
      );

      await for (final chunk in provider.generateStream(messages)) {
        accumulated += chunk;
        streamBuffer += chunk;

        // Process found markers atomics
        while (true) {
          final match = markerBlockRegex.firstMatch(streamBuffer);
          if (match == null) break;

          // 1. Yield text BEFORE the marker
          final preText = streamBuffer.substring(0, match.start);
          if (preText.trim().isNotEmpty) {
            yield AgentStep(type: AgentStepType.text, content: preText);
          }

          // 2. Identify and yield the marker itself
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
            final payload = parts.length > 1
                ? parts.sublist(1).join('|').trim()
                : '';
            yield AgentStep(
              type: AgentStepType.busEvent,
              content: '$type: $payload',
              toolName: type,
              toolParams: {'payload': payload},
            );
          }

          // 3. Consume the match from buffer
          streamBuffer = streamBuffer.substring(match.end);
        }

        // If we see the start of a tool call in the buffer, stop yielding text and wait for the rest
        if (streamBuffer.contains('<tool_call>')) {
          continue;
        }

        // "Prefix Safety": Don't yield text if the buffer ends with a partial marker
        bool isPotentiallyMarker = false;
        final markers = [taskMarker, eventMarker, '<tool_call>'];
        for (final m in markers) {
          for (int i = 1; i < m.length; i++) {
            if (streamBuffer.endsWith(m.substring(0, i))) {
              isPotentiallyMarker = true;
              break;
            }
          }
          if (isPotentiallyMarker) break;
        }

        if (!isPotentiallyMarker && streamBuffer.length > 30) {
          // Yield the safe content. We keep a small bit back just in case
          // a marker arrived split exactly at a character boundary.
          final safeLength = streamBuffer.length - 10;
          final safeText = streamBuffer.substring(0, safeLength);
          if (safeText.isNotEmpty) {
            yield AgentStep(type: AgentStepType.text, content: safeText);
          }
          streamBuffer = streamBuffer.substring(safeLength);
        }
      }

      // Final flush
      if (streamBuffer.isNotEmpty && !accumulated.contains('<tool_call>')) {
        yield AgentStep(type: AgentStepType.text, content: streamBuffer);
      }

      // Look for tool calls in the accumulated text
      final match = _toolCallRegex.firstMatch(accumulated);

      if (match == null) {
        // No tool call — this is the final answer
        // If there was a partial tool-call prefix, yield it as text
        if (accumulated.contains('<tool_call>')) {
          // Malformed tool call — just yield as text
          yield AgentStep(type: AgentStepType.text, content: accumulated);
        }
        continueLoop = false;
      } else {
        // Extract and execute the tool call
        String rawJson = match.group(1)?.trim() ?? '';
        rawJson = rawJson
            .replaceAll(RegExp(r'^```[a-zA-Z]*\n?'), '')
            .replaceAll(RegExp(r'\n?```$'), '')
            .trim();
        Map<String, dynamic> callData;

        try {
          callData = jsonDecode(rawJson) as Map<String, dynamic>;
        } catch (e) {
          final errMsg = 'Invalid tool call format: $e.\nReceived RAW JSON:\n$rawJson';
          yield AgentStep(
            type: AgentStepType.toolResult,
            content: 'Your last `<tool_call>` contained invalid JSON syntax. Do not wrap the JSON in Markdown. Please fix and retry.',
            toolName: 'error',
          );
          final errorMsg = ChatMessage(
            role: MessageRole.user,
            content: 'SYSTEM ERROR: Failed to parse your `<tool_call>` JSON. Error: $e.\nPlease output ONLY valid JSON inside the `<tool_call>` tags and try again.',
          );
          messages.add(ChatMessage(role: MessageRole.model, content: accumulated));
          messages.add(errorMsg);
          toolCallCount++;
          continue; // Loop again, giving the LLM a chance to fix its mistake
        }

        final toolName = callData['name'] as String? ?? '';
        final params = Map<String, dynamic>.from(callData)..remove('name');

        // Emit tool call step (shown in UI)
        yield AgentStep(
          type: AgentStepType.toolCall,
          content: _describeToolCall(toolName, params),
          toolName: toolName,
          toolParams: params,
        );

        // Find and execute the tool
        final tool = _tools.firstWhere(
          (t) => t.name == toolName,
          orElse: () => _UnknownTool(toolName),
        );

        String result;
        try {
          result = await tool.execute(params);
        } catch (e) {
          result = 'Tool error: $e';
        }

        // Emit the tool result step (shown in UI)
        // If it's a screenshot, don't stream the giant base64 string to the UI
        final displayResult =
            toolName == 'take_screenshot' && !result.startsWith('Error')
            ? '[Screenshot captured natively]'
            : result;

        yield AgentStep(
          type: AgentStepType.toolResult,
          content: displayResult,
          toolName: toolName,
          toolParams: params,
        );

        // Inject result back into message history for next loop
        final toolCallMsg = ChatMessage(
          role: MessageRole.model,
          content: accumulated,
        );

        String resultText = result;
        Uint8List? imageBytes;

        if (toolName == 'take_screenshot' && !result.startsWith('Error')) {
          try {
            imageBytes = base64Decode(result);
            resultText =
                'Screenshot captured successfully and attached as an image. Analyze it to verify the UI.';
          } catch (e) {
            resultText = 'Failed to decode screenshot: $e';
          }
        }

        final toolResultMsg = ChatMessage(
          role: MessageRole.user,
          content:
              'TOOL_RESULT for $toolName:\n$resultText\n\nContinue your answer.',
          images: imageBytes != null ? [imageBytes] : null,
        );

        messages.add(toolCallMsg);
        messages.add(toolResultMsg);
        toolCallCount++;
      }
    }

    if (toolCallCount > maxToolCalls) {
      yield const AgentStep(
        type: AgentStepType.text,
        content: '\n\n*(Reached maximum tool call limit)*',
      );
    }
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
      case 'take_screenshot':
        return 'Capturing device screenshot...';
      default:
        final p = Map<String, dynamic>.from(params)..remove('content');
        return '$toolName: ${p.isNotEmpty ? jsonEncode(p) : ''}';
    }
  }
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
