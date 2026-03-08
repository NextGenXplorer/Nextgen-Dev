import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/conversation.dart';
import '../../infrastructure/services/conversation_service.dart';
import '../../infrastructure/keystore_service.dart';
import '../themes.dart';

class AppDrawer extends ConsumerStatefulWidget {
  final String? currentConversationId;
  final void Function(Conversation) onConversationSelected;
  final VoidCallback onNewChat;

  const AppDrawer({
    super.key,
    required this.currentConversationId,
    required this.onConversationSelected,
    required this.onNewChat,
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
      backgroundColor: AppThemes.surfaceDark,
      width: MediaQuery.of(context).size.width * 0.82,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(0),
          bottomRight: Radius.circular(0),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Profile Row
            _buildProfileRow(context),
            const Divider(height: 1, color: AppThemes.dividerColor),
            const SizedBox(height: 12),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: AppThemes.textPrimary, fontSize: 14),
                onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, color: AppThemes.textSecondary, size: 18),
                  hintText: 'Search conversations',
                  hintStyle: const TextStyle(color: AppThemes.textSecondary, fontSize: 14),
                  filled: true,
                  fillColor: AppThemes.surfaceCard,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Chat History Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Chat history',
                    style: TextStyle(
                      color: AppThemes.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      widget.onNewChat();
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppThemes.accentBlue.withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'New chat',
                        style: TextStyle(
                          color: AppThemes.accentBlue,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
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
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text('Error: $e', style: const TextStyle(color: AppThemes.textSecondary)),
                ),
                data: (conversations) {
                  final filtered = _searchQuery.isEmpty
                      ? conversations
                      : conversations
                          .where((c) => c.title.toLowerCase().contains(_searchQuery))
                          .toList();

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text(
                        'No conversations yet.\nStart a new chat!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppThemes.textSecondary, fontSize: 14),
                      ),
                    );
                  }

                  return _buildGroupedList(filtered);
                },
              ),
            ),

            // Settings row
            const Divider(height: 1, color: AppThemes.dividerColor),
            ListTile(
              leading: const Icon(Icons.settings_outlined, color: AppThemes.textSecondary, size: 20),
              title: const Text('Settings', style: TextStyle(color: AppThemes.textSecondary, fontSize: 14)),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed('/settings');
              },
              dense: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Text(
                _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _userName,
              style: const TextStyle(
                color: AppThemes.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Icon(Icons.chevron_right, color: AppThemes.textSecondary, size: 18),
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
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
      child: Text(
        label,
        style: const TextStyle(
          color: AppThemes.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildConversationTile(Conversation c) {
    final isActive = c.id == widget.currentConversationId;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? AppThemes.accentBlue.withAlpha(25) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: const Icon(Icons.chat_bubble_outline, color: AppThemes.textSecondary, size: 18),
        title: Text(
          c.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isActive ? AppThemes.accentBlue : AppThemes.textPrimary,
            fontSize: 14,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        dense: true,
        onTap: () {
          widget.onConversationSelected(c);
          Navigator.of(context).pop();
        },
        trailing: isActive
            ? const Icon(Icons.circle, color: AppThemes.accentBlue, size: 8)
            : null,
      ),
    );
  }
}
