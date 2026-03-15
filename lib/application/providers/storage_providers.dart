import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../infrastructure/storage/workspace_manager.dart';

final workspaceManagerProvider = Provider<WorkspaceManager>((ref) {
  return WorkspaceManager();
});

final workspaceRootPathProvider = FutureProvider<String>((ref) async {
  final manager = ref.watch(workspaceManagerProvider);
  return await manager.getWorkspaceRootPath();
});
