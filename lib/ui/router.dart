import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_shell.dart';
import 'screens/projects_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/terminal_screen.dart';
import 'screens/deploy_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/editor_screen.dart';
import 'screens/project_explorer_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final shellNavigatorKey = GlobalKey<NavigatorState>();

final router = GoRouter(
  initialLocation: '/',
  navigatorKey: rootNavigatorKey,
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    ShellRoute(
      navigatorKey: shellNavigatorKey,
      builder: (context, state, child) => HomeShell(child: child),
      routes: [
        GoRoute(
          path: '/home/projects',
          builder: (context, state) => const ProjectsScreen(),
          routes: [
            GoRoute(
              path: ':id',
              builder: (context, state) =>
                  ProjectExplorerScreen(id: state.pathParameters['id']!),
              routes: [
                GoRoute(
                  path: 'editor/:path',
                  builder: (context, state) => EditorScreen(
                    projectId: state.pathParameters['id']!,
                    filePath: state.pathParameters['path']!,
                  ),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/home/chat',
          builder: (context, state) => const ChatScreen(),
        ),
        GoRoute(
          path: '/home/terminal',
          builder: (context, state) => const TerminalScreen(),
        ),
        GoRoute(
          path: '/home/deploy',
          builder: (context, state) => const DeployScreen(),
        ),
      ],
    ),
  ],
);
