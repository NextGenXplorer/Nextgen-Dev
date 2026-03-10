import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';
import '../../application/providers/terminal_service_provider.dart';
import '../themes.dart';

class TerminalWidget extends ConsumerStatefulWidget {
  final String? sessionId;
  const TerminalWidget({super.key, this.sessionId});

  @override
  ConsumerState<TerminalWidget> createState() => _TerminalWidgetState();
}

class _TerminalWidgetState extends ConsumerState<TerminalWidget> {
  late final Terminal _terminal;
  StreamSubscription? _bridgeSubscription;

  @override
  void initState() {
    super.initState();
    _terminal = Terminal();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initProcessBridge();
    });
  }

  void _initProcessBridge() async {
    final terminalService = ref.read(terminalServiceProvider);
    
    // Use the provided sessionId or create a default one
    String sid = widget.sessionId ?? '';
    if (sid.isEmpty) {
      final session = await terminalService.createSession(title: 'Default');
      sid = session.id;
    }

    final bridge = terminalService.getBridge(sid);
    if (bridge == null) return;

    _bridgeSubscription = bridge.outStream.listen((data) {
      if (mounted) {
        _terminal.write(data);
      }
    });

    _terminal.onOutput = (String data) {
      bridge.write(data);
    };
  }

  @override
  void dispose() {
    _bridgeSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppThemes.bgDark, // True blackish for terminal
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Terminal Output
          Expanded(
            child: TerminalView(
              _terminal,
              textStyle: const TerminalStyle(
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ),
          // Mobile Terminal Key Bar Placeholder
          Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF161618),
              border: Border(top: BorderSide(color: Colors.white.withAlpha(10), width: 0.5)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildKey('ESC', () => _terminal.keyInput(TerminalKey.escape)),
                  const SizedBox(width: 6),
                  _buildKey('TAB', () => _terminal.keyInput(TerminalKey.tab)),
                  const SizedBox(width: 6),
                  _buildKey('CTRL', () => {}), // Placeholder for modifier
                  const SizedBox(width: 6),
                  _buildKey('ALT', () => {}),  // Placeholder for modifier
                  const SizedBox(width: 6),
                  _buildKey('↑', () => _terminal.keyInput(TerminalKey.arrowUp)),
                  const SizedBox(width: 6),
                  _buildKey('↓', () => _terminal.keyInput(TerminalKey.arrowDown)),
                  const SizedBox(width: 6),
                  _buildKey('←', () => _terminal.keyInput(TerminalKey.arrowLeft)),
                  const SizedBox(width: 6),
                  _buildKey('→', () => _terminal.keyInput(TerminalKey.arrowRight)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKey(String label, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white.withAlpha(5), width: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: AppThemes.textPrimary,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
