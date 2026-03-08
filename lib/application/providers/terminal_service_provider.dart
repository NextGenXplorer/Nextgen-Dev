import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../infrastructure/services/terminal_service.dart';

final terminalServiceProvider = Provider<TerminalService>((ref) {
  final service = TerminalService();
  service.bootstrapPRoot(); // Trigger bootstrapping
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

final terminalSessionsProvider = Provider((ref) {
  final service = ref.watch(terminalServiceProvider);
  return service.sessions;
});
