import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/conversation.dart';
import '../../domain/models/chat_message.dart';

final conversationServiceProvider = Provider<ConversationService>((ref) {
  return ConversationService();
});

final conversationListProvider = FutureProvider<List<Conversation>>((ref) async {
  final service = ref.watch(conversationServiceProvider);
  return service.loadAll();
});

class ConversationService {
  static const String _key = 'conversations';
  final _uuid = const Uuid();

  String generateId() => _uuid.v4();

  Future<List<Conversation>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw
        .map((e) {
          try {
            return Conversation.fromJson(json.decode(e) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<Conversation>()
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> save(Conversation conversation) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await loadAll();

    // Replace if exists, otherwise insert
    final idx = all.indexWhere((c) => c.id == conversation.id);
    if (idx >= 0) {
      all[idx] = conversation;
    } else {
      all.insert(0, conversation);
    }

    await prefs.setStringList(
      _key,
      all.map((c) => json.encode(c.toJson())).toList(),
    );
  }

  Future<void> delete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await loadAll();
    all.removeWhere((c) => c.id == id);
    await prefs.setStringList(
      _key,
      all.map((c) => json.encode(c.toJson())).toList(),
    );
  }

  /// Auto-generates a title from the first user message
  String generateTitle(List<ChatMessage> messages) {
    final firstUser = messages.firstWhere(
      (m) => m.role == MessageRole.user,
      orElse: () => const ChatMessage(role: MessageRole.user, content: 'New Chat'),
    );
    final title = firstUser.content;
    return title.length > 40 ? '${title.substring(0, 40)}...' : title;
  }
}
