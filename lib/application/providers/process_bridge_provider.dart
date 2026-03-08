import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../infrastructure/services/process_bridge.dart';

final processBridgeProvider = Provider<ProcessBridge>((ref) {
  final bridge = ProcessBridge();
  ref.onDispose(() {
    bridge.dispose();
  });
  return bridge;
});
