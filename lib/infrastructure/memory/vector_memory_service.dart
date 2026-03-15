import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Simplified Vector representation
typedef Vector = List<double>;

/// Represents a distinct piece of knowledge the agent has learned.
class MemoryNode {
  final String id;
  final String content;       // e.g. "To fix the layout overflow, always wrap ListView with Expanded."
  final Vector? embedding;    // Vector representation of the content
  final DateTime createdAt;

  MemoryNode({
    required this.id,
    required this.content,
    this.embedding,
    required this.createdAt,
  });
}

/// Abstract interface for calculating cosine similarity or generating embeddings.
abstract class EmbeddingsService {
  Future<Vector> generateEmbedding(String text);
}

/// The local vector memory service using sqflite + sqlite-vss (or similar mechanism).
class VectorMemoryService {
  // Mocking the sqlite-vss or Chroma implementation for architectural clarity
  final List<MemoryNode> _localStore = [];
  final EmbeddingsService embeddingsService;

  VectorMemoryService({required this.embeddingsService});

  /// The LLM uses this to dump a new learning into the long-term memory.
  Future<void> storeKnowledge(String content) async {
    final embedding = await embeddingsService.generateEmbedding(content);
    
    final node = MemoryNode(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      embedding: embedding,
      createdAt: DateTime.now(),
    );
    
    _localStore.add(node);
    // In actual implementation: INSERT INTO vss_memory (content, embedding) VALUES (...)
    debugPrint('Agent memorized: $content');
  }

  /// The LLM automatically queries this when planning or when stuck.
  Future<List<String>> searchRelatedKnowledge(String query, {int limit = 3}) async {
    final queryVector = await embeddingsService.generateEmbedding(query);
    
    // In actual implementation: SELECT content FROM vss_memory WHERE vss_search(embedding, queryVector) LIMIT 3
    
    // Mocking vector search locally in dart:
    final results = _localStore
        // .where((n) => cosineSimilarity(n.embedding, queryVector) > 0.75)
        .take(limit)
        .map((n) => n.content)
        .toList();
        
    return results;
  }
}
