import 'package:http/http.dart' as http;
import 'agent_tool.dart';

class UrlReaderTool implements AgentTool {
  @override
  String get name => 'read_url';

  @override
  String get displayName => 'Reading URL';

  @override
  String get uiIcon => 'link';

  @override
  String get description => '''read_url: Fetch and read the text content of a web page.
Parameters: {"url": "<full URL starting with https://>"}
Use this to read articles, documentation, or any web page. Returns plain text content.''';

  @override
  Future<String> execute(Map<String, dynamic> params) async {
    final url = params['url'] as String? ?? '';
    if (url.isEmpty || (!url.startsWith('http'))) {
      return 'Error: valid url parameter required (must start with http/https)';
    }

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (compatible; AIAgent/1.0)',
          'Accept': 'text/html,application/xhtml+xml',
        },
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        return 'Failed to read URL: HTTP ${response.statusCode}';
      }

      final raw = response.body;
      final text = _stripHtml(raw);

      // Return first 3000 chars to avoid context overflow
      if (text.length > 3000) {
        return '${text.substring(0, 3000)}\n\n[Content truncated — ${text.length} total chars]';
      }
      return text.isNotEmpty ? text : 'No readable text content found on this page.';
    } catch (e) {
      return 'Error reading URL: $e';
    }
  }

  String _stripHtml(String html) {
    // Remove script and style blocks
    var text = html
        .replaceAll(RegExp(r'<script[^>]*>.*?</script>', dotAll: true, caseSensitive: false), ' ')
        .replaceAll(RegExp(r'<style[^>]*>.*?</style>', dotAll: true, caseSensitive: false), ' ')
        .replaceAll(RegExp(r'<head[^>]*>.*?</head>', dotAll: true, caseSensitive: false), ' ')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')       // strip tags
        .replaceAll(RegExp(r'&nbsp;'), ' ')
        .replaceAll(RegExp(r'&amp;'), '&')
        .replaceAll(RegExp(r'&lt;'), '<')
        .replaceAll(RegExp(r'&gt;'), '>')
        .replaceAll(RegExp(r'&quot;'), '"')
        .replaceAll(RegExp(r'\s+'), ' ')            // collapse whitespace
        .trim();
    return text;
  }
}
