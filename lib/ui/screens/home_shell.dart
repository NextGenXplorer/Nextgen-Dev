import 'package:flutter/material.dart';
import '../themes.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemes.bgDark,
      body: child,
    );
  }
}
