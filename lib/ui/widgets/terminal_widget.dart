import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';
import '../../application/providers/terminal_service_provider.dart';

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
      color: Colors.black, // True black for terminal
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
            height: 40,
            color: const Color(0xFF1E1E1E),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildKey('ESC', () => _terminal.keyInput(TerminalKey.escape)),
                _buildKey('TAB', () => _terminal.keyInput(TerminalKey.tab)),
                _buildKey('↑', () => _terminal.keyInput(TerminalKey.arrowUp)),
                _buildKey('↓', () => _terminal.keyInput(TerminalKey.arrowDown)),
                _buildKey('←', () => _terminal.keyInput(TerminalKey.arrowLeft)),
                _buildKey('→', () => _terminal.keyInput(TerminalKey.arrowRight)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKey(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ),
    );
  }
}
