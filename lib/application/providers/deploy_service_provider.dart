import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../infrastructure/services/deploy_service.dart';
import '../agent_bus.dart';

final deployServiceProvider = ChangeNotifierProvider<DeployService>((ref) {
  final agentBus = ref.watch(agentBusProvider);
  return DeployService(agentBus);
});
