import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/chat_message.dart' as app_models;
import '../../domain/models/conversation.dart';
import '../../domain/models/agent_step.dart';
import '../../application/providers/ai_service_provider.dart';
import '../../infrastructure/keystore_service.dart';
import '../../infrastructure/services/conversation_service.dart';
import '../../infrastructure/agent/agent_service.dart';
import '../themes.dart';
import '../widgets/app_drawer.dart';
import '../widgets/model_picker_sheet.dart';
import '../widgets/tool_step_bubble.dart';
import '../widgets/implementation_plan_bubble.dart';

// ─── Mode chip data ───────────────────────────────────────────────
class _ModeChip {
  final String label;
  final IconData icon;
  const _ModeChip(this.label, this.icon);
}

const _modes = [
  _ModeChip('Agent', Icons.smart_toy_outlined),
  _ModeChip('Code', Icons.code),
  _ModeChip('Deep Think', Icons.psychology_outlined),
  _ModeChip('Web', Icons.language_outlined),
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

  // All chat items (messages + agent steps interspersed)
  List<_ChatItem> _items = [];
  // Pure messages for AI context (no steps)
  List<app_models.ChatMessage> _messages = [];

  bool _isRunning = false;
  String _selectedMode = 'Agent';
  String? _currentConversationId;

  late AnimationController _dotController;

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _loadProvider();
  }

  Future<void> _loadProvider() async {
    final ks = ref.read(keystoreServiceProvider);
    final p = await ks.retrieve('SELECTED_AI_PROVIDER') ?? 'gemini';
    if (mounted) ref.read(_selectedModelProvider.notifier).state = p;
  }

  @override
  void dispose() {
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

    setState(() {
      _items = [..._items, _ChatItem.message(userMsg)];
      _messages = [..._messages, userMsg];
      _isRunning = true;
    });
    _scrollToBottom();

    final aiProvider = await ref.read(aiProviderServiceProvider.future);
    if (aiProvider == null) {
      _addSystemMsg('⚠️ No AI provider configured. Tap the model name above to add a key.');
      return;
    }

    // Start agent with current mode
    final agent = AgentService(
      provider: aiProvider,
      mode: _selectedMode,
    );

    // Placeholder for accumulating AI response text
    String currentAiText = '';
    bool aiMsgStarted = false;
    int aiMsgIndex = -1;

    try {
      await for (final step in agent.run(_messages)) {
        if (!mounted) break;

        switch (step.type) {
          case AgentStepType.toolCall:
          case AgentStepType.toolResult:
            // Show tool step inline
            setState(() => _items = [..._items, _ChatItem.step(step)]);
            _scrollToBottom();
            break;

          case AgentStepType.text:
          case AgentStepType.finalAnswer:
            // Stream text into the AI response bubble
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

      // Add final AI message to context
      if (currentAiText.isNotEmpty) {
        _messages = [
          ..._messages,
          app_models.ChatMessage(
            role: app_models.MessageRole.model,
            content: currentAiText,
          ),
        ];
        await _saveConversation();
      }
    } catch (e) {
      _addSystemMsg('Error: $e\n\nCheck your API key in ⚙️ Settings');
    } finally {
      if (mounted) setState(() => _isRunning = false);
    }
  }

  void _addSystemMsg(String text) {
    if (!mounted) return;
    setState(() {
      _items = [
        ..._items,
        _ChatItem.message(app_models.ChatMessage(
          role: app_models.MessageRole.system,
          content: text,
        )),
      ];
      _isRunning = false;
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
    await svc.save(Conversation(
      id: id,
      title: svc.generateTitle(_messages),
      provider: model,
      createdAt: DateTime.now(),
      messages: _messages,
    ));
    ref.invalidate(conversationListProvider);
  }

  void _newChat() {
    setState(() {
      _items = [];
      _messages = [];
      _currentConversationId = null;
      _isRunning = false;
    });
  }

  void _loadConversation(Conversation c) {
    setState(() {
      _messages = c.messages;
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
      backgroundColor: AppThemes.bgDark,
      drawer: AppDrawer(
        currentConversationId: _currentConversationId,
        onConversationSelected: _loadConversation,
        onNewChat: _newChat,
      ),
      appBar: _buildAppBar(modelDesc),
      body: Column(
        children: [
          Expanded(
            child: _items.isEmpty
                ? _buildWelcome(modelDesc)
                : _buildItemList(),
          ),
          if (_isRunning) _buildThinking(),
          _buildModeBar(),
          _buildInput(),
        ],
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(ModelDescriptor modelDesc) {
    return AppBar(
      backgroundColor: AppThemes.bgDark,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.menu, color: AppThemes.textPrimary),
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
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down,
                color: AppThemes.textSecondary, size: 18),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.add_circle_outline, color: AppThemes.textPrimary),
          onPressed: _newChat,
          tooltip: 'New chat',
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined, color: AppThemes.textPrimary),
          onPressed: () => context.push('/settings'),
        ),
      ],
    );
  }

  // ── Welcome screen ────────────────────────────────────────────────
  Widget _buildWelcome(ModelDescriptor modelDesc) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        const SizedBox(height: 24),
        Center(
          child: AnimatedBuilder(
            animation: _dotController,
            builder: (_, child) => Transform.scale(
              scale: 0.95 + 0.05 * _dotController.value,
              child: child,
            ),
            child: Container(
              width: 68, height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [modelDesc.iconColor, modelDesc.iconColor.withAlpha(160)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: modelDesc.iconColor.withAlpha(90),
                    blurRadius: 20, spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(modelDesc.icon, color: Colors.white, size: 32),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Your AI Agent',
          style: TextStyle(
            color: AppThemes.textPrimary,
            fontSize: 24, fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Ask anything — I can search the web, read pages,\nanalyze code, and think deeply.',
          style: TextStyle(
            color: AppThemes.textSecondary,
            fontSize: 14, height: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        // Mode pill
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppThemes.accentBlue.withAlpha(25),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppThemes.accentBlue.withAlpha(60)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.electric_bolt, color: AppThemes.accentBlue, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    '$_selectedMode mode active',
                    style: const TextStyle(
                      color: AppThemes.accentBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        ..._suggestions.map(
          (s) => GestureDetector(
            onTap: () => _send(s.replaceAll(RegExp(r'^.{2}\s+'), '')),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppThemes.surfaceCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppThemes.dividerColor, width: 0.5),
              ),
              child: Text(
                s,
                style: const TextStyle(color: AppThemes.textPrimary, fontSize: 14),
              ),
            ),
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
    _send('Please build the project according to this implementation plan:\n\n$planContent\n\nUse the build_project tool and ensure all tasks are tracked.');
  }

  Widget _buildBubble(app_models.ChatMessage msg) {
    final isUser = msg.role == app_models.MessageRole.user;
    final isSystem = msg.role == app_models.MessageRole.system;

    if (isSystem) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF7A1515).withAlpha(180),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          msg.content,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
      );
    }

    if (!isUser && msg.content.trim().startsWith('# Implementation Plan')) {
      return ImplementationPlanBubble(
        content: msg.content,
        onDevelop: () => _onDevelopPlan(msg.content),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 28, height: 28,
              margin: const EdgeInsets.only(right: 10, top: 2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppThemes.accentBlue, Color(0xFF1D4ED8)],
                ),
              ),
              child: const Icon(Icons.smart_toy_outlined, size: 14, color: Colors.white),
            ),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () {
                Clipboard.setData(ClipboardData(text: msg.content));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Copied'),
                    duration: Duration(seconds: 1),
                    backgroundColor: AppThemes.surfaceCard,
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isUser
                      ? AppThemes.accentBlue.withAlpha(40)
                      : AppThemes.surfaceCard,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isUser ? 16 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 16),
                  ),
                  border: isUser
                      ? Border.all(color: AppThemes.accentBlue.withAlpha(60))
                      : null,
                ),
                child: isUser
                    ? Text(
                        msg.content,
                        style: const TextStyle(
                          color: AppThemes.textPrimary, fontSize: 14, height: 1.4,
                        ),
                      )
                    : MarkdownBody(
                        data: msg.content.isEmpty ? '▌' : msg.content,
                        selectable: true,
                        styleSheet: MarkdownStyleSheet(
                          p: const TextStyle(
                            color: AppThemes.textPrimary, fontSize: 14, height: 1.5,
                          ),
                          code: const TextStyle(
                            fontFamily: 'monospace', fontSize: 13,
                            color: Color(0xFF93C5FD),
                            backgroundColor: Color(0xFF1E293B),
                          ),
                          codeblockDecoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          h1: const TextStyle(
                            color: AppThemes.textPrimary, fontSize: 18, fontWeight: FontWeight.w700,
                          ),
                          h2: const TextStyle(
                            color: AppThemes.textPrimary, fontSize: 16, fontWeight: FontWeight.w600,
                          ),
                          listBullet: const TextStyle(color: AppThemes.accentBlue),
                          blockquoteDecoration: BoxDecoration(
                            color: AppThemes.accentBlue.withAlpha(15),
                            border: const Border(
                              left: BorderSide(color: AppThemes.accentBlue, width: 3),
                            ),
                          ),
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
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _dotController,
            builder: (_, __) => Row(
              children: List.generate(3, (i) {
                final opacity =
                    ((_dotController.value + i * 0.33) % 1.0).clamp(0.2, 1.0);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Opacity(
                    opacity: opacity,
                    child: Container(
                      width: 6, height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppThemes.accentBlue,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Agent is working...',
            style: TextStyle(color: AppThemes.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ── Mode bar ─────────────────────────────────────────────────────
  Widget _buildModeBar() {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: _modes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final mode = _modes[i];
          final active = _selectedMode == mode.label;
          return GestureDetector(
            onTap: () => setState(() => _selectedMode = mode.label),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: active ? AppThemes.accentBlue.withAlpha(25) : AppThemes.surfaceCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active ? AppThemes.accentBlue : AppThemes.dividerColor,
                  width: active ? 1.2 : 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(mode.icon,
                      size: 14,
                      color: active ? AppThemes.accentBlue : AppThemes.textSecondary),
                  const SizedBox(width: 5),
                  Text(
                    mode.label,
                    style: TextStyle(
                      color: active ? AppThemes.accentBlue : AppThemes.textSecondary,
                      fontSize: 13,
                      fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Input bar ─────────────────────────────────────────────────────
  Widget _buildInput() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 140),
          decoration: BoxDecoration(
            color: AppThemes.surfaceCard,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppThemes.dividerColor, width: 0.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 14, bottom: 12),
                child: Icon(Icons.mic_none_outlined,
                    color: AppThemes.textSecondary, size: 22),
              ),
              Expanded(
                child: TextField(
                  controller: _textController,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  style: const TextStyle(
                      color: AppThemes.textPrimary, fontSize: 15),
                  decoration: const InputDecoration(
                    hintText: 'Ask your agent...',
                    hintStyle: TextStyle(
                        color: AppThemes.textSecondary, fontSize: 15),
                    border: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 8, vertical: 12),
                  ),
                  onSubmitted: (_) {
                    if (!_isRunning) _send();
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 6, bottom: 6),
                child: GestureDetector(
                  onTap: _isRunning ? null : _send,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isRunning
                          ? AppThemes.textSecondary.withAlpha(60)
                          : AppThemes.accentBlue,
                    ),
                    child: Icon(
                      _isRunning ? Icons.hourglass_top : Icons.arrow_upward,
                      color: Colors.white, size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
