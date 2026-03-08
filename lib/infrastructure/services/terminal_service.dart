import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import '../../domain/models/terminal_session.dart';
import 'process_bridge.dart';

class TerminalService {
  final List<TerminalSession> _sessions = [];
  final Map<String, ProcessBridge> _bridges = {};
  
  List<TerminalSession> get sessions => List.unmodifiable(_sessions);

  Future<void> bootstrapPRoot() async {
    if (!Platform.isAndroid) return;

    try {
      final docDir = await getApplicationDocumentsDirectory();
      
      // 1. Ensure rootfs directory exists
      final rootfsDir = Directory('${docDir.path}/ubuntu_rootfs');
      if (!await rootfsDir.exists()) {
        await rootfsDir.create(recursive: true);
        debugPrint('PRoot: Created ubuntu_rootfs directory.');
      }

      // 2. Extract proot_launcher.sh from assets
      final launcherFile = File('${docDir.path}/proot_launcher.sh');
      try {
        final data = await rootBundle.load('assets/proot_launcher.sh');
        final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        await launcherFile.writeAsBytes(bytes);
        // Ensure it's executable
        if (!Platform.isWindows) {
          await Process.run('chmod', ['+x', launcherFile.path]);
        }
        debugPrint('PRoot: Extracted proot_launcher.sh to ${launcherFile.path}');
      } catch (e) {
        debugPrint('PRoot: Note - proot_launcher.sh asset not found, using fallback: $e');
        // Fallback or skip if asset doesn't exist yet
      }

      // 3. Note for developer: proot binary and rootfs tarball should ideally be 
      // downloaded or included in assets. For now, we allow the shell to run.
      
    } catch (e) {
      debugPrint('Error during Terminal bootstrapping: $e');
    }
  }

  Future<TerminalSession> createSession({String? title, String? shell, bool isRoot = false}) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final session = TerminalSession(
      id: id,
      title: title ?? 'Session ${_sessions.length + 1}',
      shell: shell ?? 'sh',
      isRoot: isRoot,
      lastActive: DateTime.now(),
    );

    _sessions.add(session);
    
    final bridge = ProcessBridge();
    _bridges[id] = bridge;
    await bridge.launch();

    return session;
  }

  ProcessBridge? getBridge(String sessionId) => _bridges[sessionId];

  void closeSession(String sessionId) {
    _sessions.removeWhere((s) => s.id == sessionId);
    _bridges[sessionId]?.dispose();
    _bridges.remove(sessionId);
  }

  void dispose() {
    for (var bridge in _bridges.values) {
      bridge.dispose();
    }
    _bridges.clear();
    _sessions.clear();
  }
}
