import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ui/router.dart';
import 'ui/themes.dart';
import 'infrastructure/storage/workspace_manager.dart';
import 'infrastructure/services/crash_reporting_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Workspace & Permissions
  final workspace = WorkspaceManager();
  await workspace.initializeWorkspace();

  // 2. Initialize Telemetry/Analytics
  final crashlytics = CrashReportingService();
  await crashlytics.initialize();

  runApp(const ProviderScope(child: MobileAiIdeApp()));
}

class MobileAiIdeApp extends StatelessWidget {
  const MobileAiIdeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Mobile AI IDE',
      theme: AppThemes.lightTheme,
      darkTheme: AppThemes.darkTheme,
      themeMode: ThemeMode.dark, // Default to dark theme as per PRD
      routerConfig: router,
    );
  }
}
