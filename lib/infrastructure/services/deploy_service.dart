import 'package:flutter/foundation.dart';
import '../../domain/models/agent_event.dart';
import '../../application/agent_bus.dart';

enum DeployStatus { idle, building, deploying, success, failure }

class DeployService extends ChangeNotifier {
  final AgentBus _agentBus;
  DeployStatus _status = DeployStatus.idle;
  String _message = '';
  double _progress = 0.0;
  final List<String> _logs = [];

  DeployStatus get status => _status;
  String get message => _message;
  double get progress => _progress;
  List<String> get logs => List.unmodifiable(_logs);

  DeployService(this._agentBus) {
    _agentBus.eventStream.listen((event) {
      if (event.type == AgentEventType.deployStatusUpdate) {
        final payload = event.payload as Map<String, dynamic>?;
        if (payload != null) {
          _updateFromPayload(payload);
        }
      }
    });
  }

  void _updateFromPayload(Map<String, dynamic> payload) {
    if (payload.containsKey('status')) {
      _status = DeployStatus.values.firstWhere(
        (e) => e.name == payload['status'],
        orElse: () => DeployStatus.idle,
      );
    }
    if (payload.containsKey('message')) {
      _message = payload['message'] as String;
      if (_message.isNotEmpty) {
        _logs.add('[${DateTime.now().toString().substring(11, 19)}] $_message');
      }
    }
    _progress = (payload['progress'] as num?)?.toDouble() ?? _progress;
    notifyListeners();
  }

  void startDeploy() {
    _logs.clear();
    _status = DeployStatus.building;
    _message = 'Initiating environment deployment...';
    _progress = 0.0;
    _logs.add('[${DateTime.now().toString().substring(11, 19)}] Deployment sequence initiated by user.');
    notifyListeners();
    
    // Notify agents that deployment started
    _agentBus.publish(AgentEvent(
      sourceAgent: 'DeployService',
      targetAgent: 'All',
      type: AgentEventType.taskStarted,
      payload: {'task': 'deploy'},
    ));
  }
}
