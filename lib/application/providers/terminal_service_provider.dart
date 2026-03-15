import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../infrastructure/services/terminal_service.dart';
import 'storage_providers.dart';
import '../agent_bus.dart';

final terminalServiceProvider = ChangeNotifierProvider<TerminalService>((ref) {
  final manager = ref.watch(workspaceManagerProvider);
  final agentBus = ref.watch(agentBusProvider);
  final service = TerminalService(manager, agentBus);
  return service;
});

final terminalSessionsProvider = Provider((ref) {
  final service = ref.watch(terminalServiceProvider);
  return service.sessions;
});
