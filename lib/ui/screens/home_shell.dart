import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../themes.dart';
import '../widgets/flower_menu.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.child});

  final Widget child;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  // Initial position for the floating menu (bottom center roughly)
  Offset _menuPosition = const Offset(0, 0);
  bool _isMenuInitialized = false;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final index = _indexFor(location);

    return Scaffold(
      backgroundColor: AppThemes.bgDark,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Initialize position once based on screen size
          if (!_isMenuInitialized) {
            _menuPosition = Offset(
              constraints.maxWidth / 2 - 140, // 140 is half of FlowerMenu width
              constraints.maxHeight - 280, // Bottom alignment
            );
            _isMenuInitialized = true;
          }

          return Stack(
            children: [
              widget.child,
              Positioned(
                left: _menuPosition.dx,
                top: _menuPosition.dy,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      // Update position, constrained to screen bounds
                      _menuPosition = Offset(
                        (_menuPosition.dx + details.delta.dx).clamp(
                          -140.0 + 28, // Allow hanging off slightly
                          constraints.maxWidth - 140.0 - 28,
                        ),
                        (_menuPosition.dy + details.delta.dy).clamp(
                          0.0,
                          constraints.maxHeight - 280 + 200, // keep button visible
                        ),
                      );
                    });
                  },
                  child: FlowerMenu(currentIndex: index),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static int _indexFor(String path) {
    if (path.startsWith('/home/projects')) return 0;
    if (path.startsWith('/home/chat')) return 1;
    if (path.startsWith('/home/terminal')) return 2;
    if (path.startsWith('/home/deploy')) return 3;
    return 1;
  }
}

