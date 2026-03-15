import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import '../themes.dart';

class CodeElementBuilder extends MarkdownElementBuilder {
  final BuildContext context;

  CodeElementBuilder(this.context);

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    if (element.tag != 'code' || element.children == null || element.children!.isEmpty) {
      return null;
    }

    // Determine if this is a block of code (pre > code) or inline
    bool isCodeBlock = element.attributes['class']?.startsWith('language-') == true;

    final String textContent = element.textContent;

    if (!isCodeBlock) {
      // Inline code
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: AppThemes.surfaceDark.withAlpha(200),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          textContent,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            color: Color(0xFF93C5FD), // Light blue for inline
          ),
        ),
      );
    }

    // It is a block of code
    final language = element.attributes['class']?.substring(9) ?? 'text'; // 'language-' is 9 chars

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24), // Very dark background for the code box
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(20), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(10),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Text(
                  language,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.copy_rounded, color: Colors.white54, size: 14),
                const SizedBox(width: 16),
                const Icon(Icons.wrap_text_rounded, color: Colors.white54, size: 14),
                const SizedBox(width: 16),
                // Code | Preview Segmented Control concept
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(50),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(20),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Code',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        child: const Text(
                          'Preview',
                          style: TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Code Content
          Container(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                textContent,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: Color(0xFFD4D4D8), // Light grey text
                  height: 1.5,
                ),
              ),
            ),
          ),
          
          // Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.white.withAlpha(10), width: 1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.volume_up_outlined, color: Colors.white54, size: 18),
                const Spacer(),
                const Icon(Icons.content_copy_outlined, color: Colors.white54, size: 18),
                const SizedBox(width: 20),
                const Icon(Icons.thumb_up_alt_outlined, color: Colors.white54, size: 18),
                const SizedBox(width: 20),
                const Icon(Icons.thumb_down_alt_outlined, color: Colors.white54, size: 18),
                const SizedBox(width: 20),
                const Icon(Icons.shortcut_outlined, color: Colors.white54, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
