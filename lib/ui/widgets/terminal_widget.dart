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
  final ScrollController _scrollController = ScrollController();
  StreamSubscription? _bridgeSubscription;
  bool _ctrlMode = false;

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(maxLines: 10000);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initProcessBridge();
    });
  }

  void _initProcessBridge() async {
    final terminalService = ref.read(terminalServiceProvider);

    String sid = widget.sessionId ?? '';
    if (sid.isEmpty) {
      final session = await terminalService.createSession(title: 'Default');
      sid = session.id;
    }

    final bridge = terminalService.getBridge(sid);
    if (bridge == null) return;

    // Wire the bridge output stream → xterm
    _bridgeSubscription = bridge.outStream.listen((data) {
      if (mounted) {
        _terminal.write(data);
      }
    });

    // Wire xterm keyboard input → bridge PTY
    _terminal.onOutput = (String data) {
      bridge.write(data);
    };
  }

  /// Sends a Ctrl+key sequence to the terminal.
  /// e.g., 'c' → Ctrl+C (ASCII 0x03), 'l' → Ctrl+L (clear), etc.
  void _sendCtrlKey(String key) {
    final charCode = key.toLowerCase().codeUnitAt(0);
    // ASCII control codes: Ctrl+A = 0x01, Ctrl+B = 0x02 ... Ctrl+Z = 0x1A
    if (charCode >= 0x61 && charCode <= 0x7A) {
      final ctrlChar = String.fromCharCode(charCode - 0x60);
      final bridge = ref.read(terminalServiceProvider).getBridge(widget.sessionId ?? '');
      bridge?.write(ctrlChar);
    }
  }

  @override
  void dispose() {
    _bridgeSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Terminal Output ───────────────────────────────────────────────────
        Expanded(
          child: Stack(
            children: [
              Container(
                color: const Color(0xFF060608),
                child: RawScrollbar(
                  thumbVisibility: true,
                  interactive: true,
                  thickness: 10,
                  radius: const Radius.circular(5),
                  thumbColor: AppThemes.accentCyan.withAlpha(220),
                  controller: _scrollController,
                  child: TerminalView(
                    _terminal,
                    scrollController: _scrollController,
                    textStyle: const TerminalStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                    theme: TerminalTheme(
                      cursor: AppThemes.accentCyan,
                      selection: AppThemes.accentCyan.withAlpha(80),
                      foreground: const Color(0xFFE8EAF0),
                      background: const Color(0xFF060608),
                      black: Colors.black,
                      red: const Color(0xFFFF5F57),
                      green: const Color(0xFF28C840),
                      yellow: const Color(0xFFFFBD2E),
                      blue: AppThemes.accentCyan,
                      magenta: const Color(0xFFB48EAD),
                      cyan: AppThemes.accentCyan,
                      white: const Color(0xFFE8EAF0),
                      brightBlack: const Color(0xFF636363),
                      brightRed: const Color(0xFFFF5F57),
                      brightGreen: const Color(0xFF28C840),
                      brightYellow: const Color(0xFFFFBD2E),
                      brightBlue: AppThemes.accentCyan,
                      brightMagenta: const Color(0xFFB48EAD),
                      brightCyan: AppThemes.accentCyan,
                      brightWhite: Colors.white,
                      searchHitBackground: AppThemes.accentGold.withAlpha(120),
                      searchHitBackgroundCurrent: AppThemes.accentGold,
                      searchHitForeground: Colors.black,
                    ),
                  ),
                ),
              ),
              // Floating Scroll to Bottom button
              Positioned(
                right: 16,
                bottom: 16,
                child: Opacity(
                  opacity: 0.6,
                  child: FloatingActionButton.small(
                    onPressed: () => _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    ),
                    backgroundColor: Colors.black54,
                    child: const Icon(Icons.keyboard_arrow_down, color: AppThemes.accentCyan),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Mobile Key Bar ────────────────────────────────────────────────────
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F12),
            border: Border(
              top: BorderSide(
                color: AppThemes.dividerColor.withAlpha(60),
                width: 0.5,
              ),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const AlwaysScrollableScrollPhysics(),
            child: Row(
              children: [
                // CTRL — toggles Ctrl-modifier mode
                _buildModifierKey(
                  'CTRL',
                  isActive: _ctrlMode,
                  onTap: () => setState(() => _ctrlMode = !_ctrlMode),
                ),
                const SizedBox(width: 6),

                // Fast-tap Ctrl shortcuts
                if (_ctrlMode) ...[
                  _buildCtrlShortcut('C'),
                  const SizedBox(width: 6),
                  _buildCtrlShortcut('D'),
                  const SizedBox(width: 6),
                  _buildCtrlShortcut('Z'),
                  const SizedBox(width: 6),
                  _buildCtrlShortcut('L'),
                  const SizedBox(width: 6),
                  _buildCtrlShortcut('A'),
                  const SizedBox(width: 6),
                  _buildCtrlShortcut('E'),
                ] else ...[
                  _buildKey(
                    'TAB',
                    () => _terminal.keyInput(TerminalKey.tab),
                  ),
                  const SizedBox(width: 6),
                  _buildKey(
                    'ESC',
                    () => _terminal.keyInput(TerminalKey.escape),
                  ),
                  const SizedBox(width: 6),
                  _buildKey(
                    '↑',
                    () => _terminal.keyInput(TerminalKey.arrowUp),
                  ),
                  const SizedBox(width: 6),
                  _buildKey(
                    '↓',
                    () => _terminal.keyInput(TerminalKey.arrowDown),
                  ),
                  const SizedBox(width: 6),
                  _buildKey(
                    '←',
                    () => _terminal.keyInput(TerminalKey.arrowLeft),
                  ),
                  const SizedBox(width: 6),
                  _buildKey(
                    '→',
                    () => _terminal.keyInput(TerminalKey.arrowRight),
                  ),
                  const SizedBox(width: 6),
                  _buildKey(
                    'HOME',
                    () => _terminal.keyInput(TerminalKey.home),
                  ),
                  const SizedBox(width: 6),
                  _buildKey(
                    'END',
                    () => _terminal.keyInput(TerminalKey.end),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModifierKey(
    String label, {
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isActive
                ? AppThemes.accentCyan.withAlpha(25)
                : Colors.transparent,
            border: Border.all(
              color: isActive
                  ? AppThemes.accentCyan.withAlpha(120)
                  : Colors.white.withAlpha(15),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(6),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppThemes.accentCyan.withAlpha(30),
                      blurRadius: 6,
                    )
                  ]
                : [],
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? AppThemes.accentCyan : AppThemes.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  /// Ctrl+key shortcut chip (shown when CTRL mode is active)
  Widget _buildCtrlShortcut(String key) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _sendCtrlKey(key);
          setState(() => _ctrlMode = false); // auto-release after action
        },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppThemes.accentCyan.withAlpha(15),
            border: Border.all(
              color: AppThemes.accentCyan.withAlpha(60),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '^$key',
            style: const TextStyle(
              color: AppThemes.accentCyan,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKey(String label, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.white.withAlpha(15),
              width: 0.5,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: AppThemes.textPrimary.withAlpha(200),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
