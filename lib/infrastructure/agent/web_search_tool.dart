import 'dart:convert';
import 'package:http/http.dart' as http;
import 'agent_tool.dart';

class WebSearchTool implements AgentTool {
  @override
  String get name => 'web_search';

  @override
  String get displayName => 'Web Search';

  @override
  String get uiIcon => 'search';

  @override
  String get description => '''web_search: Search the internet for current information.
Parameters: {"query": "<search query string>"}
Use this when you need current information, facts, news, or any data you don't know.''';

  @override
  Future<String> execute(Map<String, dynamic> params) async {
    final query = params['query'] as String? ?? '';
    if (query.isEmpty) return 'Error: query parameter is required';

    try {
      // DuckDuckGo Instant Answer API — free, no key needed
      final uri = Uri.parse(
        'https://api.duckduckgo.com/?q=${Uri.encodeComponent(query)}&format=json&no_html=1&skip_disambig=1',
      );
      final response = await http.get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return 'Search failed: HTTP ${response.statusCode}';
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      final results = StringBuffer();
      results.writeln('Search results for: "$query"\n');

      // Abstract (main answer)
      final abstract = data['Abstract'] as String? ?? '';
      if (abstract.isNotEmpty) {
        results.writeln('📌 Summary: $abstract');
        results.writeln('Source: ${data['AbstractURL'] ?? ''}');
        results.writeln();
      }

      // Answer (short direct answer)
      final answer = data['Answer'] as String? ?? '';
      if (answer.isNotEmpty) {
        results.writeln('⚡ Direct Answer: $answer\n');
      }

      // Related topics
      final topics = (data['RelatedTopics'] as List<dynamic>? ?? [])
          .take(5)
          .whereType<Map<String, dynamic>>();

      if (topics.isNotEmpty) {
        results.writeln('Related results:');
        for (final t in topics) {
          final text = t['Text'] as String? ?? '';
          final url = (t['FirstURL'] as String? ?? '');
          if (text.isNotEmpty) {
            results.writeln('• $text');
            if (url.isNotEmpty) results.writeln('  URL: $url');
          }
        }
      }

      if (results.toString().trim() == 'Search results for: "$query"') {
        // Fallback: no results from DDG, return query acknowledgment
        return 'No direct results found for "$query". Consider using read_url with a specific URL.';
      }

      return results.toString();
    } catch (e) {
      return 'Search error: $e';
    }
  }
}
