import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../themes.dart';

class FlowerMenu extends StatefulWidget {
  final int currentIndex;

  const FlowerMenu({super.key, required this.currentIndex});

  @override
  State<FlowerMenu> createState() => _FlowerMenuState();
}

class _FlowerMenuState extends State<FlowerMenu>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isOpen = false;

  final List<_NavItem> _navItems = const [
    _NavItem(
      label: 'Projects',
      icon: Icons.folder_outlined,
      iconActive: Icons.folder,
      route: '/home/projects',
    ),
    _NavItem(
      label: 'Chat',
      icon: Icons.chat_bubble_outline,
      iconActive: Icons.chat_bubble,
      route: '/home/chat',
    ),
    _NavItem(
      label: 'Terminal',
      icon: Icons.terminal_outlined,
      iconActive: Icons.terminal,
      route: '/home/terminal',
    ),
    _NavItem(
      label: 'Deploy',
      icon: Icons.cloud_upload_outlined,
      iconActive: Icons.cloud_upload,
      route: '/home/deploy',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  void _onItemTapped(String route) {
    _toggleMenu();
    context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 280,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // The background overlay (optional, but good for blocking touches)
          if (_isOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggleMenu,
                behavior: HitTestBehavior.opaque,
                child: Container(color: Colors.transparent),
              ),
            ),

          // Menu Items
          ...List.generate(_navItems.length, (index) {
            return _buildMenuItem(index);
          }),

          // Center Togger
          Positioned(bottom: 24, child: _buildToggler()),
        ],
      ),
    );
  }

  Widget _buildMenuItem(int index) {
    final item = _navItems[index];
    final isActive = widget.currentIndex == index;

    // Distribute items in a semi-circle upwards.
    // Angles between 165 degrees (left) and 15 degrees (right).
    // Start angle: pi * (165/180), End angle: pi * (15/180)
    // 4 items -> step = (165 - 15) / 3 = 50 degrees
    // Angles: 165, 115, 65, 15
    final double startAngle = 165.0;
    final double step = 50.0;
    final double angleDeg = startAngle - (index * step);
    final double angleRad = angleDeg * (math.pi / 180.0);

    // The radius from the center button to the menu items
    final double radius = 100.0;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double animValue = CurvedAnimation(
          parent: _controller,
          curve: Interval(0.1 * index, 1.0, curve: Curves.easeOutBack),
        ).value;

        // Position based on polar coordinates
        final double x = math.cos(angleRad) * radius * animValue;
        final double y = -math.sin(angleRad) * radius * animValue;

        return Positioned(
          bottom:
              24 +
              12, // match toggler center vertically if Toggler size is 56, 24 + (56/2) - (itemSize/2). Let's just say 24 center.
          child: Transform.translate(
            offset: Offset(x, y),
            child: Transform.scale(
              scale: animValue,
              child: Opacity(
                opacity: _controller.value > 0.1 ? 1.0 : 0.0,
                child: child,
              ),
            ),
          ),
        );
      },
      child: GestureDetector(
        onTap: () => _onItemTapped(item.route),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? AppThemes.accentCyan : AppThemes.surfaceCard,
            border: Border.all(
              color: isActive
                  ? AppThemes.accentCyan.withAlpha(100)
                  : AppThemes.dividerColor,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(80),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
              if (isActive)
                BoxShadow(
                  color: AppThemes.accentCyan.withAlpha(100),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isActive ? item.iconActive : item.icon,
                color: isActive ? Colors.white : AppThemes.textPrimary,
                size: 20,
              ),
              const SizedBox(height: 2),
              Text(
                item.label,
                style: TextStyle(
                  color: isActive ? Colors.white : AppThemes.textSecondary,
                  fontSize: 8,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggler() {
    return GestureDetector(
      onTap: _toggleMenu,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [AppThemes.accentCyan, Color(0xFF1D4ED8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppThemes.accentCyan.withAlpha(100),
              blurRadius: 12,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: _isOpen
                ? const Icon(
                    Icons.close,
                    key: ValueKey('close'),
                    color: Colors.white,
                    size: 28,
                  )
                : const Icon(
                    Icons.smart_toy_outlined, // Kimi-like Agent icon
                    key: ValueKey('toy'),
                    color: Colors.white,
                    size: 28,
                  ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final IconData iconActive;
  final String route;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.iconActive,
    required this.route,
  });
}
