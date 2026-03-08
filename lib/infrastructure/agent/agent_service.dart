import 'dart:convert';
import '../../domain/models/chat_message.dart';
import '../../domain/models/agent_step.dart';
import '../../domain/interfaces/ai_provider.dart';
import 'agent_tool.dart';
import 'web_search_tool.dart';
import 'url_reader_tool.dart';
import 'build_project_tool.dart';

// ── Mode-specific system prompts ──────────────────────────────────────────────
const _agentSystemPrompt = '''You are a powerful AI assistant with real-time internet access and tools.

You have access to these tools — call them using EXACTLY this format when you need information:
<tool_call>{"name": "web_search", "query": "your search query"}</tool_call>
<tool_call>{"name": "read_url", "url": "https://example.com/page"}</tool_call>
<tool_call>{"name": "build_project", "id": "uuid", "name": "Project Name", "description": "...", "files": [...], "tasks": [{"id": "t1", "title": "Setup", "status": "done"}, {"id": "t2", "title": "Implementation", "status": "todo"}]}</tool_call>

Rules:
- ALWAYS use web_search for current events, news, prices, facts that may have changed
- Use read_url when you need specific details from a webpage found in search results
- Only call ONE tool per response
- After getting tool results, you will receive them prefixed with TOOL_RESULT and can continue reasoning
- Give thorough, well-structured final answers using markdown
- For complex requests, start by providing an "# Implementation Plan" with a "## Tasks" checklist section.
- You are running inside a mobile AI IDE app called NextGen
''';

const _codeSystemPrompt = '''You are an expert software engineer and coding assistant.

Specialties: Flutter/Dart, Python, JavaScript/TypeScript, React, Node.js, SQL, system design.

Rules:
- Always provide complete, working code
- Use proper code blocks with language tags (```dart, ```python, etc.)
- Explain your code clearly with comments
- Point out potential bugs and edge cases
- Suggest best practices and optimizations
- For Flutter: follow widget tree best practices and use proper state management
- For complex requests, start by providing an "# Implementation Plan" with a "## Tasks" checklist section.
- You have a tool called `build_project` to save complete codebases. Use it when the user asks to "build", "generate", or "develop" the app according to a plan.
  <tool_call>{"name": "build_project", "id": "optional-uuid", "name": "App Name", "description": "...", "files": [...], "tasks": [...]}</tool_call>
- Task Tracking: Use the `tasks` parameter to track progress. If you are continuing a project, read the project files (including metadata.json) to see what tasks are already done.
''';

const _deepThinkSystemPrompt = '''You are an expert analytical assistant that thinks deeply before answering.

Approach every question by:
1. Breaking it down into components
2. Considering multiple perspectives and approaches
3. Identifying assumptions and potential flaws
4. Reasoning step by step, showing your work
5. Arriving at a well-justified conclusion

Use markdown headers and bullet points to structure your reasoning clearly.
Be thorough — the user wants depth, not speed.
''';

const _webSystemPrompt = '''You are a web research assistant with real-time internet access.

ALWAYS start by searching the web for current information before answering.
<tool_call>{"name": "web_search", "query": "..."}</tool_call>

Then if you need more details, read specific pages:
<tool_call>{"name": "read_url", "url": "..."}</tool_call>

Synthesize multiple sources into a comprehensive, well-cited answer.
Always mention your sources.
''';

// ── Tool call regex ───────────────────────────────────────────────────────────
final _toolCallRegex = RegExp(
  r'<tool_call>(.*?)</tool_call>',
  dotAll: true,
);

// ── AgentService ──────────────────────────────────────────────────────────────
class AgentService {
  final AIProvider provider;
  final String mode;
  final int maxToolCalls;

  final List<AgentTool> _tools = [
    WebSearchTool(),
    UrlReaderTool(),
    BuildProjectTool(),
  ];

  AgentService({
    required this.provider,
    this.mode = 'Agent',
    this.maxToolCalls = 5,
  });

  String _systemPrompt() {
    switch (mode) {
      case 'Code':
        return _codeSystemPrompt;
      case 'Deep Think':
        return _deepThinkSystemPrompt;
      case 'Web':
        return _webSystemPrompt;
      case 'Agent':
      default:
        return _agentSystemPrompt;
    }
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

      // Stream the AI response
      await for (final chunk in provider.generateStream(messages)) {
        accumulated += chunk;

        // Check if a complete tool_call tag has appeared
        if (accumulated.contains('</tool_call>')) {
          break; // Stop streaming, process the tool call
        }

        // Yield text chunks only if no tool call prefix yet
        if (!accumulated.contains('<tool_call>')) {
          yield AgentStep(type: AgentStepType.text, content: chunk);
        }
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
        final rawJson = match.group(1)?.trim() ?? '';
        Map<String, dynamic> callData;

        try {
          callData = jsonDecode(rawJson) as Map<String, dynamic>;
        } catch (_) {
          yield AgentStep(
            type: AgentStepType.toolResult,
            content: 'Invalid tool call format',
            toolName: 'error',
          );
          continueLoop = false;
          break;
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
        yield AgentStep(
          type: AgentStepType.toolResult,
          content: result,
          toolName: toolName,
        );

        // Inject result back into message history for next loop
        final toolCallMsg = ChatMessage(
          role: MessageRole.model,
          content: accumulated,
        );
        final toolResultMsg = ChatMessage(
          role: MessageRole.user,
          content: 'TOOL_RESULT for $toolName:\n$result\n\nContinue your answer.',
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
        return params['query'] as String? ?? 'Searching...';
      case 'read_url':
        return params['url'] as String? ?? 'Reading page...';
      case 'build_project':
        return 'Building project "${params['name']}"...';
      default:
        return jsonEncode(params);
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
