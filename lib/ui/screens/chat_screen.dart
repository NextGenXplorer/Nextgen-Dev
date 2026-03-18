import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/models/chat_message.dart' as app_models;
import '../../domain/models/conversation.dart';
import '../../domain/models/agent_step.dart';
import '../../application/providers/ai_service_provider.dart';
import '../../application/providers/agent_session_provider.dart';
import '../../infrastructure/keystore_service.dart';
import '../../infrastructure/services/conversation_service.dart';
import '../../infrastructure/agent/agent_service.dart';
import '../../application/agent_bus.dart';
import '../../application/agent_orchestrator.dart';
import '../../application/providers/storage_providers.dart';
import '../themes.dart';
import '../widgets/app_drawer.dart';
import '../widgets/model_picker_sheet.dart';
import '../widgets/tool_step_bubble.dart';
import '../widgets/implementation_plan_bubble.dart';
import '../widgets/code_element_builder.dart';
import '../../domain/models/agent_event.dart';
import '../widgets/agent_task_progress_bubble.dart';
import '../widgets/agent_completion_bubble.dart';

// ─── Mode chip data ───────────────────────────────────────────────
class _ModeChip {
  final String label;
  final IconData icon;
  const _ModeChip(this.label, this.icon);
}

const _modes = [
  _ModeChip('Agent', Icons.face_retouching_natural_outlined),
  _ModeChip('Websites', Icons.language_outlined),
  _ModeChip('Slides', Icons.cast_for_education_outlined),
  _ModeChip('Deep Search', Icons.document_scanner_outlined),
];

// ─── Suggestion prompts ───────────────────────────────────────────
const _suggestions = [
  '🔍  Search the web: latest AI model releases 2025',
  '💻  Help me write a Flutter Riverpod provider',
  '🧠  Explain quantum computing step by step',
];

// ─── Chat item: can be a message or an agent step ─────────────────
class _ChatItem {
  final app_models.ChatMessage? message;
  final AgentStep? step;
  _ChatItem.message(this.message) : step = null;
  _ChatItem.step(this.step) : message = null;
}

final _selectedModelProvider = StateProvider<String>((ref) => 'gemini');

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with SingleTickerProviderStateMixin {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  // Chat items (messages + agent steps) — local UI list only.
  // Agent-generated content (tasks, plan, messages) lives in agentSessionProvider.
  List<_ChatItem> _items = [];

  String _selectedMode = 'Chat';
  String? _currentConversationId;

  // Stop token — set to true to abort the agent loop
  bool _stopRequested = false;

  late AnimationController _dotController;
  StreamSubscription<AgentEvent>? _busSubscription;

  // Convenience getters — read from global session so they survive navigation
  bool get _isRunning => ref.read(agentSessionProvider).isRunning;
  List<AgentTask> get _currentTasks => ref.read(agentSessionProvider).tasks;
  List<String> get _changedFiles => ref.read(agentSessionProvider).changedFiles;
  String? get _lastProjectId => ref.read(agentSessionProvider).activeProjectId;
  String? get _activeProjectPath => ref.read(agentSessionProvider).activeProjectPath;
  Map<String, dynamic>? get _lastPlanPayload => ref.read(agentSessionProvider).lastPlanPayload;
  List<app_models.ChatMessage> get _messages => ref.read(agentSessionProvider).chatHistory;
  bool get _awaitingRequirements => ref.read(agentSessionProvider).awaitingRequirements;
  String? get _pendingRequirementsTask => ref.read(agentSessionProvider).pendingRequirementsTask;

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _loadProvider();

    _busSubscription = ref.read(agentBusProvider).eventStream.listen((event) {
      if (!mounted) return;

      // Update global session state for lifecycle events
      final session = ref.read(agentSessionProvider.notifier);

      if (event.type == AgentEventType.planReady) {
        final payload = event.payload as Map<String, dynamic>;
        session.setPlan(payload['plan'] ?? '', payload);
        // Requirements phase is done — clear the flag.
        session.setAwaitingRequirements(false);
        setState(() {});
      }

      if (event.type == AgentEventType.agentFinished) {
        session.setRunning(false);
        setState(() {});
      }

      if (event.type == AgentEventType.taskUpdate) {
        _handleTaskUpdate(event.payload.toString());
      }

      // RequirementsAgent signals — track the Q&A phase.
      if (event.type == AgentEventType.awaitingRequirements) {
        final p = event.payload;
        String? originalTask;
        if (p is Map<String, dynamic>) originalTask = p['originalTask'] as String?;
        session.setAwaitingRequirements(true, originalTask: originalTask);
        session.setRunning(false);
        setState(() {});
      }

      if (event.type == AgentEventType.requirementsGathered) {
        // Requirements are locked in, PlannerAgent will take over.
        session.setAwaitingRequirements(false);
        session.setRunning(true);
        setState(() {});
      }

      if (_selectedMode == 'Team' || _selectedMode == 'Agent') {
        if (event.type == AgentEventType.agentStep) {
          final step = event.payload as AgentStep;
          setState(() => _items = [..._items, _ChatItem.step(step)]);
          _extractFileChanges(step);
        } else if (event.type == AgentEventType.message) {
          // If targeted to 'User', or from an known agent to 'System' (as a status update), we show it.
          final isUserTarget = event.targetAgent == 'User';
          final isSystemTarget = event.targetAgent == 'System';
          
          if (isUserTarget || isSystemTarget) {
            final chunk = event.payload.toString();
            
            if (_items.isEmpty || _items.last.message == null || _items.last.message!.role != app_models.MessageRole.model) {
              // Start a new model message block
              final newAiMsg = app_models.ChatMessage(
                role: app_models.MessageRole.model,
                content: chunk,
              );
              session.addMessage(newAiMsg);
              setState(() {
                _items = [..._items, _ChatItem.message(newAiMsg)];
              });
            } else {
              // Append to the existing block
              final lastMsg = _items.last.message!;
              final updatedMsg = app_models.ChatMessage(
                role: app_models.MessageRole.model,
                content: lastMsg.content + chunk,
              );
              
              setState(() {
                _items[_items.length - 1] = _ChatItem.message(updatedMsg);
              });
              session.updateLastMessage(updatedMsg);
            }
            _scrollToBottom();
          }
        }
      }

      if (event.type == AgentEventType.agentFinished || 
          event.type == AgentEventType.taskFailed) {
        session.setRunning(false);
        setState(() {});
      }

      if (event.type == AgentEventType.taskCompleted) {
        // We still might want to clear running state on CERTAIN completions as a fallback
        if (event.sourceAgent == 'PreviewAgent' || event.sourceAgent == 'DeployerAgent') {
           session.setRunning(false);
           setState(() {});
        }
      }

      _scrollToBottom();
    });
  }

  void _handleTaskUpdate(String message) {
    final regExp = RegExp(r'(?:TASK_UPDATE:\s*)?\[(.)\]\s*->\s*\[(.)\]\s*(.*)');
    final match = regExp.firstMatch(message);
    if (match != null) {
      final newStatus = match.group(2);
      final title = match.group(3)?.trim() ?? '';
      final status = _parseStatus(newStatus!);
      // Write to global session — survives navigation
      ref.read(agentSessionProvider.notifier).upsertTask(AgentTask(title: title, status: status));
      setState(() {}); // trigger rebuild
    }
  }

  TaskStatus _parseStatus(String s) {
    if (s == 'x') return TaskStatus.completed;
    if (s == '/') return TaskStatus.inProgress;
    return TaskStatus.pending;
  }

  Future<void> _loadProvider() async {
    final ks = ref.read(keystoreServiceProvider);
    final p = await ks.retrieve('SELECTED_AI_PROVIDER') ?? 'gemini';
    if (mounted) ref.read(_selectedModelProvider.notifier).state = p;
  }

  @override
  void dispose() {
    _busSubscription?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    _dotController.dispose();
    super.dispose();
  }

  // ── Send / Agent loop ────────────────────────────────────────────
  Future<void> _send([String? prefilled]) async {
    final text = prefilled ?? _textController.text.trim();
    if (text.isEmpty || _isRunning) return;
    _textController.clear();

    final userMsg = app_models.ChatMessage(
      role: app_models.MessageRole.user,
      content: text,
    );

    // Add message to global session (persists across navigation)
    final session = ref.read(agentSessionProvider.notifier);
    session.addMessage(userMsg);
    session.setRunning(true);
    setState(() {
      _items = [..._items, _ChatItem.message(userMsg)];
      _stopRequested = false;
    });
    _scrollToBottom();

    final aiProvider = await ref.read(aiProviderServiceProvider.future);
    if (aiProvider == null) {
      _addSystemMsg('⚠️ No AI provider configured. Tap the model name above to add a key.');
      session.setRunning(false);
      return;
    }

    if (_selectedMode == 'Team') {
      ref.read(orchestratorProvider).dispatchTask(text);
      return;
    }

    // Agent mode: if RequirementsAgent is awaiting answers, route back to it.
    if (_selectedMode == 'Agent' && _awaitingRequirements) {
      final originalTask = _pendingRequirementsTask ?? text;
      ref.read(orchestratorProvider).dispatchRequirementsFollowUp(
        originalTask: originalTask,
        userAnswer: text,
      );
      session.setRunning(true);
      setState(() {});
      return;
    }

    // Agent mode: new task — start with requirements gathering.
    if (_selectedMode == 'Agent') {
      ref.read(orchestratorProvider).dispatchTask(text);
      session.setRunning(true);
      setState(() {});
      return;
    }

    final workspaceManager = ref.read(workspaceManagerProvider);
    final agent = AgentService(
      provider: aiProvider,
      mode: _selectedMode,
      workspaceManager: workspaceManager,
      activeProjectPath: _activeProjectPath,
    );

    String currentAiText = '';
    bool aiMsgStarted = false;
    int aiMsgIndex = -1;

    try {
      await for (final step in agent.run(_messages)) {
        if (!mounted || _stopRequested) break;

        switch (step.type) {
          case AgentStepType.toolCall:
          case AgentStepType.toolResult:
            setState(() => _items = [..._items, _ChatItem.step(step)]);
            if (step.type == AgentStepType.toolResult) {
              _extractFileChanges(step);
            }
            _scrollToBottom();
            break;

          case AgentStepType.taskUpdate:
            _handleTaskUpdate(step.content);
            break;

          case AgentStepType.busEvent:
            final typeStr = step.toolName ?? '';
            final payload = step.toolParams?['payload'];
            AgentEventType? eventType;
            try {
              eventType = AgentEventType.values
                  .firstWhere((e) => e.toString().split('.').last == typeStr);
            } catch (_) {}
            if (eventType != null) {
              ref.read(agentBusProvider).publish(AgentEvent(
                sourceAgent: 'AgentService',
                targetAgent: 'System',
                type: eventType,
                payload: payload,
              ));
            }
            break;

          case AgentStepType.text:
          case AgentStepType.finalAnswer:
            if (!aiMsgStarted) {
              aiMsgStarted = true;
              final emptyAiMsg = app_models.ChatMessage(
                role: app_models.MessageRole.model,
                content: '',
              );
              setState(() {
                _items = [..._items, _ChatItem.message(emptyAiMsg)];
                aiMsgIndex = _items.length - 1;
              });
            }
            currentAiText += step.content;
            setState(() {
              final updatedItems = List<_ChatItem>.from(_items);
              updatedItems[aiMsgIndex] = _ChatItem.message(
                app_models.ChatMessage(
                  role: app_models.MessageRole.model,
                  content: currentAiText,
                ),
              );
              _items = updatedItems;
            });
            _scrollToBottom();
            break;
        }
      }

      // Persist final AI message to global session
      if (currentAiText.isNotEmpty) {
        final aiMsg = app_models.ChatMessage(
          role: app_models.MessageRole.model,
          content: currentAiText,
        );
        session.addMessage(aiMsg);
        await _saveConversation();
      }
    } catch (e) {
      _addSystemMsg('Error: $e\n\nCheck your API key in ⚙️ Settings');
    } finally {
      if (mounted) {
        session.setRunning(false);
        setState(() {});
      }
    }
  }

  void _addSystemMsg(String text) {
    if (!mounted) return;
    setState(() {
      _items = [
        ..._items,
        _ChatItem.message(
          app_models.ChatMessage(
            role: app_models.MessageRole.system,
            content: text,
          ),
        ),
      ];
      ref.read(agentSessionProvider.notifier).setRunning(false);
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 200,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _saveConversation() async {
    final svc = ref.read(conversationServiceProvider);
    final id = _currentConversationId ?? const Uuid().v4();
    _currentConversationId = id;
    final model = ref.read(_selectedModelProvider);
    await svc.save(
      Conversation(
        id: id,
        title: svc.generateTitle(_messages),
        provider: model,
        createdAt: DateTime.now(),
        messages: _messages,
      ),
    );
    ref.invalidate(conversationListProvider);
  }

  void _newChat() {
    // Reset global session (clears messages, tasks, running state, changedFiles, projectId)
    ref.read(agentSessionProvider.notifier).reset();
    setState(() {
      _items = [];
      _currentConversationId = null;
      _stopRequested = false;
    });
  }

  // Called from _send to track file changes

  void _extractFileChanges(AgentStep step) {
    final tool = step.toolName ?? '';
    const fileTools = ['create_file', 'edit_file', 'build_project'];
    if (!fileTools.contains(tool)) return;
    if (!step.content.startsWith('SUCCESS')) return;
    final pathMatch = RegExp(
      r'(?:file|project) ([^\s(]+)',
    ).firstMatch(step.content);
    if (pathMatch != null) {
      final p = pathMatch.group(1);
      if (p != null && !_changedFiles.contains(p)) {
        ref.read(agentSessionProvider.notifier).addChangedFile(p);
        setState(() {});
      }
    }
    if (tool == 'build_project' && step.toolParams != null) {
      final id =
          step.toolParams!['id']?.toString() ??
          step.toolParams!['name']?.toString();
      if (id != null && id.isNotEmpty) {
        ref.read(agentSessionProvider.notifier).setActiveProject(id, id);
      }
    }
  }

  // ── Files Changed Banner ────────────────────────────────────────────────
  Widget _buildFilesChangedBanner() {
    final count = _changedFiles.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
      child: GestureDetector(
        onTap: () {
          if (_lastProjectId != null) {
            context.go('/home/chat/$_lastProjectId');
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1200),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFFBBF24).withAlpha(80),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              const Text('🗂', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$count file${count == 1 ? '' : 's'} changed'
                  '${_lastProjectId != null ? '  → Open workspace' : ''}',
                  style: const TextStyle(
                    color: Color(0xFFFBBF24),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _changedFiles.clear()),
                child: const Icon(
                  Icons.close,
                  size: 15,
                  color: Color(0xFFFBBF24),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _loadConversation(Conversation c) {
    final session = ref.read(agentSessionProvider.notifier);
    for (final m in c.messages) {
      session.addMessage(m);
    }
    setState(() {
      _items = c.messages.map((m) => _ChatItem.message(m)).toList();
      _currentConversationId = c.id;
    });
    ref.read(_selectedModelProvider.notifier).state = c.provider;
    _scrollToBottom();
  }

  Future<void> _updateModel(String id) async {
    ref.read(_selectedModelProvider.notifier).state = id;
    final ks = ref.read(keystoreServiceProvider);
    await ks.store('SELECTED_AI_PROVIDER', id);
    ref.invalidate(aiProviderServiceProvider);
    _newChat();
  }

  // ── Build ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final selectedModel = ref.watch(_selectedModelProvider);
    final modelDesc = allModels.firstWhere(
      (m) => m.id == selectedModel,
      orElse: () => allModels.first,
    );

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppThemes.bgDark, // Deep obsidian base
      drawer: AppDrawer(
        currentConversationId: _currentConversationId,
        onConversationSelected: _loadConversation,
        onNewChat: _newChat,
      ),
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(modelDesc),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.8, -0.6),
            radius: 1.5,
            colors: [
              Color(0xFF0F172A), // Subtle Frosted Obsidian mesh top left
              Color(0xFF05070A), // Deep Galactic Ink base
              Color(0xFF05070A),
            ],
            stops: [0.0, 0.4, 1.0],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: _items.isEmpty
                    ? _buildWelcome(modelDesc)
                    : _buildItemList(),
              ),
              if (_isRunning) _buildThinking(),
              if (_awaitingRequirements && !_isRunning) _buildRequirementsBanner(),
              if (_changedFiles.isNotEmpty) _buildFilesChangedBanner(),
              _buildInput(),
              const SizedBox(height: 8), // Small padding for safety
            ],
          ),
        ),
      ),
    );
  }

  // ── Requirements Awaiting Banner ────────────────────────────────────────
  Widget _buildRequirementsBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFF130D21),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFA78BFA).withAlpha(90),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            const Text('📋', style: TextStyle(fontSize: 13)),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Requirements Agent is asking questions — type your answers and send',
                style: TextStyle(
                  color: Color(0xFFC4B5FD),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(ModelDescriptor modelDesc) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: Container(
        decoration: BoxDecoration(
          color: AppThemes.bgDark, // Solid background
          border: Border(
            bottom: BorderSide(
              color: Colors.white.withAlpha(5), // Extremely subtle hairline separator
              width: 0.5,
            ),
          ),
        ),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.menu_rounded,
              color: AppThemes.textPrimary,
            ),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          title: GestureDetector(
            onTap: () => showModelPicker(
              context,
              currentModel: ref.read(_selectedModelProvider),
              onModelSelected: _updateModel,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  modelDesc.name,
                  style: const TextStyle(
                    color: AppThemes.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.keyboard_arrow_right,
                  color: AppThemes.textSecondary,
                  size: 18,
                ),
              ],
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(
                Icons.volume_up_outlined,
                color: AppThemes.textPrimary,
                size: 22,
              ),
              onPressed: () {}, 
            ),
            IconButton(
              icon: const Icon(
                Icons.chat_bubble_outline,
                color: AppThemes.textPrimary,
                size: 22,
              ),
              onPressed: _newChat,
              tooltip: 'New chat',
            ),
          ],
        ),
      ),
    );
  }

  // ── Welcome screen ────────────────────────────────────────────────
  Widget _buildWelcome(ModelDescriptor modelDesc) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        const SizedBox(height: 32),
        // Blue Avatar
        Align(
          alignment: Alignment.centerLeft,
          child: AnimatedBuilder(
            animation: _dotController,
            builder: (_, child) => Transform.scale(
              scale: 0.98 + 0.02 * _dotController.value,
              child: child,
            ),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF5EB1FF), 
                    Color(0xFF2E6FF2), 
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withAlpha(100),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(radius: 3.5, backgroundColor: Colors.white),
                    SizedBox(width: 6),
                    CircleAvatar(radius: 3.5, backgroundColor: Colors.white),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        
        // Greeting Text
        Text(
          'Hi nXg, ${modelDesc.name} sees images and videos now!\nJust drop in a design and watch it turn into code. Try Agent Swarm to run complex tasks in parallel.',
          style: const TextStyle(
            color: AppThemes.textPrimary,
            fontSize: 16,
            height: 1.5,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  // ── Chat item list (messages + tool steps) ────────────────────────
  Widget _buildItemList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
      itemCount: _items.length,
      itemBuilder: (context, i) {
        final item = _items[i];
        if (item.step != null) {
          return ToolStepBubble(step: item.step!);
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildBubble(item.message!),
        );
      },
    );
  }

  void _onDevelopPlan(String planContent) {
    var payload = _lastPlanPayload;

    if (payload == null) {
      // Reconstruct payload from history if it was lost (e.g. on reload)
      String? originalTask;
      for (int i = _messages.length - 1; i >= 0; i--) {
        if (_messages[i].role == app_models.MessageRole.user) {
          originalTask = _messages[i].content;
          break;
        }
      }
      if (originalTask != null) {
        payload = {
          'originalTask': originalTask,
          'plan': planContent,
        };
      }
    }

    if (payload != null) {
      ref.read(agentBusProvider).publish(AgentEvent(
        sourceAgent: 'User',
        targetAgent: 'Orchestrator',
        type: AgentEventType.planApproved,
        payload: payload,
      ));
      // Reset tasks and mark as running in global session
      final session = ref.read(agentSessionProvider.notifier);
      session.setRunning(true);
      // Clear old tasks from session for fresh build
      for (final t in _currentTasks) {
        session.upsertTask(AgentTask(title: t.title, status: TaskStatus.pending));
      }
      setState(() {});
    }
  }

  Widget _buildBubble(app_models.ChatMessage msg) {
    final isUser = msg.role == app_models.MessageRole.user;
    final isSystem = msg.role == app_models.MessageRole.system;

    if (isSystem) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppThemes.errorRed.withAlpha(15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppThemes.errorRed.withAlpha(40)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppThemes.errorRed, size: 14),
            const SizedBox(width: 8),
            Expanded(child: Text(msg.content, style: const TextStyle(color: AppThemes.errorRed, fontSize: 12))),
          ],
        ),
      );
    }

    if (!isUser && msg.content.contains('# Implementation Plan')) {
      return ImplementationPlanBubble(
        content: msg.content,
        onProceed: () => _onDevelopPlan(msg.content),
        onEdit: () {
          _textController.text = "I'd like to adjust the plan. Please change: ";
          FocusScope.of(context).requestFocus(FocusNode()); // Focus input?
        },
      );
    }

    if (!isUser && _currentTasks.isNotEmpty && _isRunning) {
       // Only show if it matches the current session? Or just show the latest one
       return AgentTaskProgressBubble(tasks: _currentTasks);
    }

    if (!isUser && msg.content.contains('Agent finished all tasks')) {
       return AgentCompletionBubble(
         onSourceCode: () {
           if (_lastProjectId != null) {
              context.go('/home/chat/$_lastProjectId');
           } else {
              context.go('/home/projects');
           }
         },
         onPreview: () async {
           final url = Uri.parse('http://localhost:8080'); // Common dev port
           if (await canLaunchUrl(url)) {
             await launchUrl(url, mode: LaunchMode.externalApplication);
           } else {
             if (mounted) {
               ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(content: Text('Could not launch preview. Is the server running?'))
               );
             }
           }
         },
         onGithub: () {
            ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('GitHub integration placeholder activated.'))
           );
         },
         onDeploy: () {
            ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Select platform: Vercel, Netlify, Render...'))
           );
         },
       );
    }

    // FILTER: Hide code blocks in Agent mode to show only steps/progress
    String content = msg.content;
    if (_selectedMode == 'Agent' && !isUser) {
      // Remove markdown code blocks
      content = content.replaceAll(RegExp(r'```[\s\S]*?```'), '');
      if (content.trim().isEmpty) return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.only(right: 10, bottom: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E40AF), AppThemes.accentCyan],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(color: AppThemes.accentCyan.withAlpha(70), blurRadius: 10),
                ],
              ),
              child: const Icon(Icons.auto_awesome_rounded, size: 14, color: Colors.white),
            ),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () {
                Clipboard.setData(ClipboardData(text: content));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Copied to clipboard'),
                    duration: const Duration(seconds: 1),
                    backgroundColor: AppThemes.surfaceCard,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              },
              child: isUser
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(18),
                          topRight: Radius.circular(18),
                          bottomLeft: Radius.circular(18),
                          bottomRight: Radius.circular(4),
                        ),
                        border: Border.all(color: const Color(0xFF1E293B), width: 0.8),
                        boxShadow: [BoxShadow(color: Colors.black.withAlpha(60), blurRadius: 12, offset: const Offset(0, 4))],
                      ),
                      child: Text(
                        content,
                        style: const TextStyle(color: AppThemes.textPrimary, fontSize: 15, height: 1.5, fontFamily: 'Inter'),
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF080C12),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(18),
                          bottomLeft: Radius.circular(18),
                          bottomRight: Radius.circular(18),
                        ),
                        border: Border.all(color: AppThemes.accentCyan.withAlpha(20), width: 0.5),
                        boxShadow: [
                          BoxShadow(color: AppThemes.accentCyan.withAlpha(8), blurRadius: 16, spreadRadius: 1),
                          BoxShadow(color: Colors.black.withAlpha(60), blurRadius: 20, offset: const Offset(0, 6)),
                        ],
                      ),
                      child: MarkdownBody(
                        data: content.isEmpty ? '▌' : content,
                        selectable: true,
                        builders: {'code': CodeElementBuilder(context)},
                        styleSheet: MarkdownStyleSheet(
                          p: const TextStyle(color: AppThemes.textPrimary, fontSize: 15, height: 1.55, fontFamily: 'Inter'),
                          code: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: Color(0xFF7DD3FC), backgroundColor: Color(0xFF0F1929)),
                          codeblockDecoration: BoxDecoration(color: const Color(0xFF060A14), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF1E293B))),
                          h1: const TextStyle(color: AppThemes.textPrimary, fontSize: 20, fontWeight: FontWeight.w800, fontFamily: 'Inter'),
                          h2: const TextStyle(color: AppThemes.textPrimary, fontSize: 17, fontWeight: FontWeight.w700, fontFamily: 'Inter'),
                          h3: const TextStyle(color: AppThemes.textSecondary, fontSize: 15, fontWeight: FontWeight.w600),
                          listBullet: const TextStyle(color: AppThemes.accentCyan),
                          blockquoteDecoration: BoxDecoration(
                            color: AppThemes.accentCyan.withAlpha(10),
                            border: Border(left: BorderSide(color: AppThemes.accentCyan.withAlpha(120), width: 3)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          tableBorder: TableBorder.all(color: AppThemes.dividerColor, width: 0.5),
                          tableHead: const TextStyle(color: AppThemes.accentCyan, fontWeight: FontWeight.w700, fontSize: 13),
                          tableBody: const TextStyle(color: AppThemes.textPrimary, fontSize: 13),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Thinking indicator ────────────────────────────────────────────
  Widget _buildThinking() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF060D1A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppThemes.accentCyan.withAlpha(30), width: 0.8),
          boxShadow: [BoxShadow(color: AppThemes.accentCyan.withAlpha(12), blurRadius: 16, spreadRadius: 1)],
        ),
        child: Row(
          children: [
            // Glowing AI avatar
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [Color(0xFF1E40AF), AppThemes.accentCyan]),
                boxShadow: [BoxShadow(color: AppThemes.accentCyan.withAlpha(80), blurRadius: 10)],
              ),
              child: const Icon(Icons.auto_awesome_rounded, size: 13, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AGENT WORKING',
                    style: TextStyle(color: AppThemes.accentCyan, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.5, fontFamily: 'Inter'),
                  ),
                  const SizedBox(height: 4),
                  AnimatedBuilder(
                    animation: _dotController,
                    builder: (_, __) => Row(
                      children: List.generate(3, (i) {
                        final phase = (_dotController.value * 3 - i) % 3.0;
                        final opacity = (phase > 0 && phase < 1 ? phase : phase > 2 ? 3 - phase : 0.0).clamp(0.2, 1.0);
                        return Container(
                          width: 5,
                          height: 5,
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppThemes.accentCyan.withOpacity(opacity),
                            boxShadow: [BoxShadow(color: AppThemes.accentCyan.withOpacity(opacity * 0.4), blurRadius: 4)],
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
            // Stop button
            GestureDetector(
              onTap: () => setState(() => _stopRequested = true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppThemes.errorRed.withAlpha(15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppThemes.errorRed.withAlpha(60)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.stop_rounded, size: 11, color: AppThemes.errorRed),
                    SizedBox(width: 4),
                    Text('Stop', style: TextStyle(color: AppThemes.errorRed, fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'Inter')),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Mode bar ───────────────────────────────────────────────────────
  Widget _buildModeBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: _modes.map((mode) {
          final isSelected = _selectedMode == mode.label;
          final chipColor = mode.label == 'Agent'
              ? AppThemes.accentCyan
              : mode.label == 'Websites'
                  ? const Color(0xFF818CF8)
                  : mode.label == 'Slides'
                      ? const Color(0xFFFFD700)
                      : const Color(0xFF4ADE80);

          return GestureDetector(
            onTap: () => setState(() => _selectedMode = mode.label),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected ? chipColor.withAlpha(20) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? chipColor.withAlpha(120) : Colors.white.withAlpha(15),
                  width: isSelected ? 1 : 0.6,
                ),
                boxShadow: isSelected
                    ? [BoxShadow(color: chipColor.withAlpha(30), blurRadius: 8)]
                    : [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    mode.icon,
                    size: 14,
                    color: isSelected ? chipColor : Colors.white.withAlpha(100),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    mode.label,
                    style: TextStyle(
                      color: isSelected ? chipColor : Colors.white.withAlpha(100),
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Input bar ─────────────────────────────────────────────────────
  Widget _buildInput() {
    final hasText = _textController.text.isNotEmpty;
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildModeBar(),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 160),
              decoration: BoxDecoration(
                color: const Color(0xFF080D16),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isRunning
                      ? AppThemes.accentCyan.withAlpha(60)
                      : const Color(0xFF1E293B),
                  width: _isRunning ? 1 : 0.8,
                ),
                boxShadow: [
                  if (_isRunning)
                    BoxShadow(color: AppThemes.accentCyan.withAlpha(20), blurRadius: 16, spreadRadius: 2),
                  BoxShadow(color: Colors.black.withAlpha(60), blurRadius: 20, offset: const Offset(0, -4)),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 14),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        _selectedMode == 'Agent'
                            ? Icons.auto_awesome_rounded
                            : _selectedMode == 'Websites'
                                ? Icons.language_rounded
                                : _selectedMode == 'Slides'
                                    ? Icons.cast_for_education_rounded
                                    : Icons.travel_explore_rounded,
                        color: _isRunning
                            ? AppThemes.accentCyan
                            : Colors.white.withAlpha(80),
                        size: 20,
                        key: ValueKey(_selectedMode),
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      style: const TextStyle(
                        color: AppThemes.textPrimary,
                        fontSize: 15,
                        fontFamily: 'Inter',
                        height: 1.4,
                      ),
                      decoration: InputDecoration(
                        hintText: _selectedMode == 'Agent'
                            ? 'Tell the agent what to build...'
                            : _selectedMode == 'Websites'
                                ? 'Describe the website you want...'
                                : 'Ask anything...',
                        hintStyle: TextStyle(color: Colors.white.withAlpha(35), fontSize: 14, fontFamily: 'Inter'),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      ),
                      onSubmitted: (_) { if (!_isRunning) _send(); },
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 12, bottom: 10),
                    child: GestureDetector(
                      onTap: () {
                        if (_isRunning) {
                          setState(() => _stopRequested = true);
                        } else if (hasText) {
                          _send();
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: _isRunning
                                ? [AppThemes.errorRed, const Color(0xFFF97316)]
                                : hasText
                                    ? [const Color(0xFF1E40AF), AppThemes.accentCyan]
                                    : [const Color(0xFF1E293B), const Color(0xFF1E293B)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: (hasText || _isRunning)
                              ? [
                                  BoxShadow(
                                    color: (_isRunning ? AppThemes.errorRed : AppThemes.accentCyan).withAlpha(80),
                                    blurRadius: 12,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : [],
                        ),
                        child: Icon(
                          _isRunning ? Icons.stop_rounded : Icons.arrow_upward_rounded,
                          color: (hasText || _isRunning) ? Colors.white : Colors.white.withAlpha(40),
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
