import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/conversation.dart';
import '../../infrastructure/services/conversation_service.dart';
import '../../infrastructure/keystore_service.dart';
import '../themes.dart';
import 'package:go_router/go_router.dart';

class AppDrawer extends ConsumerStatefulWidget {
  final String? currentConversationId;
  final void Function(Conversation)? onConversationSelected;
  final VoidCallback? onNewChat;

  const AppDrawer({
    super.key,
    this.currentConversationId,
    this.onConversationSelected,
    this.onNewChat,
  });

  @override
  ConsumerState<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends ConsumerState<AppDrawer> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _userName = 'User';

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final keystore = ref.read(keystoreServiceProvider);
    final name = await keystore.retrieve('USER_NAME');
    if (mounted && name != null) {
      setState(() => _userName = name);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conversationsAsync = ref.watch(conversationListProvider);

    return Drawer(
      backgroundColor: const Color(0xFF0A0A0C),
      width: MediaQuery.of(context).size.width * 0.85,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: Colors.white.withAlpha(10), width: 0.5),
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Profile Row
              _buildProfileRow(context),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Divider(height: 1, color: Colors.white.withAlpha(10)),
              ),
              const SizedBox(height: 20),

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(
                    color: AppThemes.textPrimary,
                    fontSize: 13,
                  ),
                  onChanged: (v) =>
                      setState(() => _searchQuery = v.toLowerCase()),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppThemes.textSecondary,
                      size: 18,
                    ),
                    hintText: 'Search conversations...',
                    hintStyle: const TextStyle(
                      color: AppThemes.textSecondary,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: const Color(0xFF161618),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: Colors.white.withAlpha(10),
                        width: 0.5,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: Colors.white.withAlpha(10),
                        width: 0.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: AppThemes.accentCyan,
                        width: 1,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Workspace Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                child: Row(
                  children: const [
                    Text(
                      'WORKSPACE',
                      style: TextStyle(
                        color: AppThemes.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Workspace Navigation Items
              _buildWorkspaceNavItem(
                context,
                'Projects',
                Icons.folder_outlined,
                Icons.folder,
                '/home/projects',
              ),
              _buildWorkspaceNavItem(
                context,
                'Command (Chat)',
                Icons.smart_toy_outlined,
                Icons.smart_toy,
                '/home/chat',
              ),
              _buildWorkspaceNavItem(
                context,
                'Terminal',
                Icons.terminal_outlined,
                Icons.terminal,
                '/home/terminal',
              ),
              _buildWorkspaceNavItem(
                context,
                'Deploy',
                Icons.rocket_launch_outlined,
                Icons.rocket_launch,
                '/home/deploy',
              ),

              const SizedBox(height: 24),

              // Chat History Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'CONVERSATIONS',
                      style: TextStyle(
                        color: AppThemes.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context); // Close drawer
                        if (widget.onNewChat != null) {
                          widget.onNewChat!();
                        } else {
                          context.go('/home/chat');
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppThemes.accentCyan.withAlpha(30),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.add_rounded,
                              color: AppThemes.accentCyan,
                              size: 14,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'NEW',
                              style: TextStyle(
                                color: AppThemes.accentCyan,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Conversation list
              Expanded(
                child: conversationsAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      color: AppThemes.accentCyan,
                    ),
                  ),
                  error: (e, _) => Center(
                    child: Text(
                      'Error: $e',
                      style: const TextStyle(color: AppThemes.textSecondary),
                    ),
                  ),
                  data: (conversations) {
                    final filtered = _searchQuery.isEmpty
                        ? conversations
                        : conversations
                              .where(
                                (c) => c.title.toLowerCase().contains(
                                  _searchQuery,
                                ),
                              )
                              .toList();

                    if (filtered.isEmpty) {
                      return Center(
                        child: Text(
                          _searchQuery.isEmpty
                              ? 'No conversations yet'
                              : 'No results found',
                          style: const TextStyle(
                            color: AppThemes.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      );
                    }

                    return _buildGroupedList(filtered);
                  },
                ),
              ),

              // Settings row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Divider(height: 1, color: Colors.white.withAlpha(10)),
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.settings_rounded,
                    color: AppThemes.textPrimary,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Settings',
                  style: TextStyle(
                    color: AppThemes.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushNamed('/settings');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 16, 20),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppThemes.accentCyan, Color(0xFF6366F1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppThemes.accentCyan.withAlpha(40),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Center(
              child: Text(
                _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userName,
                  style: const TextStyle(
                    color: AppThemes.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Premium Member',
                  style: TextStyle(
                    color: AppThemes.accentCyan,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppThemes.textSecondary,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedList(List<Conversation> conversations) {
    final now = DateTime.now();
    final today = conversations.where((c) {
      final diff = now.difference(c.createdAt).inDays;
      return diff < 1;
    }).toList();
    final last7 = conversations.where((c) {
      final diff = now.difference(c.createdAt).inDays;
      return diff >= 1 && diff <= 7;
    }).toList();
    final older = conversations.where((c) {
      final diff = now.difference(c.createdAt).inDays;
      return diff > 7;
    }).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      children: [
        if (today.isNotEmpty) ...[
          _buildDateHeader('Today'),
          ...today.map((c) => _buildConversationTile(c)),
        ],
        if (last7.isNotEmpty) ...[
          _buildDateHeader('Last 7 days'),
          ...last7.map((c) => _buildConversationTile(c)),
        ],
        if (older.isNotEmpty) ...[
          _buildDateHeader('Older'),
          ...older.map((c) => _buildConversationTile(c)),
        ],
      ],
    );
  }

  Widget _buildDateHeader(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 10),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: Colors.white24,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildConversationTile(Conversation c) {
    final isActive = c.id == widget.currentConversationId;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isActive
              ? AppThemes.accentCyan.withAlpha(30)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? AppThemes.accentCyan.withAlpha(60)
                : Colors.transparent,
            width: 0.5,
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
          leading: Icon(
            Icons.chat_bubble_rounded,
            color: isActive
                ? AppThemes.accentCyan
                : AppThemes.textSecondary.withAlpha(150),
            size: 16,
          ),
          title: Text(
            c.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isActive
                  ? AppThemes.textPrimary
                  : AppThemes.textPrimary.withAlpha(200),
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          onTap: () {
            if (widget.onConversationSelected != null) {
              widget.onConversationSelected!(c);
            } else {
              context.go('/home/chat');
            }
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
    );
  }

  Widget _buildWorkspaceNavItem(
    BuildContext context,
    String label,
    IconData icon,
    IconData activeIcon,
    String route,
  ) {
    // Determine active state from current path
    final location = GoRouterState.of(context).uri.path;
    final isActive = location.startsWith(route);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isActive
              ? AppThemes.accentCyan.withAlpha(30)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? AppThemes.accentCyan.withAlpha(60)
                : Colors.transparent,
            width: 0.5,
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
          leading: Icon(
            isActive ? activeIcon : icon,
            color: isActive
                ? AppThemes.accentCyan
                : AppThemes.textSecondary.withAlpha(150),
            size: 20,
          ),
          title: Text(
            label,
            style: TextStyle(
              color: isActive
                  ? AppThemes.textPrimary
                  : AppThemes.textPrimary.withAlpha(200),
              fontSize: 14,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          onTap: () {
            if (!isActive) {
              context.go(route);
            }
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
    );
  }
}
