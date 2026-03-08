import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/agent_event.dart';

final agentBusProvider = Provider<AgentBus>((ref) => AgentBus());

class AgentBus {
  final _eventController = StreamController<AgentEvent>.broadcast();

  Stream<AgentEvent> get eventStream => _eventController.stream;

  void publish(AgentEvent event) {
    _eventController.add(event);
  }

  void dispose() {
    _eventController.close();
  }
}
