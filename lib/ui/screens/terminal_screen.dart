import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../themes.dart';
import '../widgets/terminal_widget.dart';
import '../widgets/app_drawer.dart';
import '../../application/providers/terminal_service_provider.dart';

class TerminalScreen extends ConsumerStatefulWidget {
  const TerminalScreen({super.key});

  @override
  ConsumerState<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends ConsumerState<TerminalScreen>
    with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  TabController? _tabController;

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(terminalSessionsProvider);

    // Auto-launch Ubuntu session if empty
    if (sessions.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(terminalServiceProvider).createSession(
              title: 'Ubuntu 1',
              isRoot: true,
            );
      });
    }

    // Initialize or update tab controller
    if (_tabController == null || _tabController!.length != sessions.length) {
      _tabController?.dispose();
      _tabController = TabController(
        length: sessions.length,
        vsync: this,
        initialIndex: sessions.isNotEmpty ? (sessions.length - 1) : 0,
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.transparent,
      drawer: const AppDrawer(currentConversationId: null),
      body: Stack(
        children: [
          // Background - Glassmorphism
          Container(decoration: const BoxDecoration(color: Color(0xFF0A0A0A))),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(color: Colors.black.withAlpha(50)),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top Bar with Tab Management
                _buildTopBar(context, sessions),

                // Terminal Space
                Expanded(
                  child: sessions.isEmpty
                      ? _buildEmptyState()
                      : TabBarView(
                          controller: _tabController,
                          physics: const BouncingScrollPhysics(), // Allow swiping between terminal sessions (Termux style)
                          children: sessions
                              .map((s) => TerminalWidget(sessionId: s.id))
                              .toList(),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, dynamic sessions) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withAlpha(20), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap: () => _scaffoldKey.currentState?.openDrawer(),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: const [
                    Icon(Icons.menu_rounded, color: Colors.white70),
                    SizedBox(width: 4),
                    Text('MENU', style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Session Tabs
          Expanded(
            child: sessions.isEmpty
                ? const SizedBox()
                : TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    labelColor: AppThemes.accentCyan,
                    unselectedLabelColor: Colors.white24,
                    indicatorColor: AppThemes.accentCyan,
                    indicatorWeight: 3,
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    tabs: sessions
                        .map<Widget>(
                          (s) => Tab(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.terminal_rounded, size: 14),
                                  const SizedBox(width: 8),
                                  Text(s.title.toUpperCase()),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () => ref
                                        .read(terminalServiceProvider)
                                        .closeSession(s.id),
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: 14,
                                      color: Colors.white.withAlpha(50),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),

          // Add Session Button
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppThemes.accentCyan),
            onPressed: () => ref
                .read(terminalServiceProvider)
                .createSession(
                  title: 'Ubuntu ${sessions.length + 1}',
                  isRoot: true,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.terminal_rounded,
            size: 64,
            color: Colors.white.withAlpha(20),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Active Sessions',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap + to launch a new Ubuntu PRoot environment',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () =>
                ref.read(terminalServiceProvider).createSession(isRoot: true),
            icon: const Icon(Icons.rocket_launch_rounded),
            label: const Text('Launch Ubuntu Environment'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppThemes.accentCyan,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }
}
