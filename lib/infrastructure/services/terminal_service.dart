import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../../domain/models/terminal_session.dart';
import 'process_bridge.dart';
import '../storage/workspace_manager.dart';
import '../../domain/models/agent_event.dart';
import '../../application/agent_bus.dart';

class TerminalService extends ChangeNotifier {
  final WorkspaceManager _workspaceManager;
  final AgentBus _agentBus;
  final List<TerminalSession> _sessions = [];
  final Map<String, ProcessBridge> _bridges = {};
  // Track setup state to avoid re-running for the same rootfs
  bool _setupComplete = false;
  StreamSubscription? _agentBusSub;

  TerminalService(this._workspaceManager, this._agentBus) {
    _initAgentBusListener();
  }

  void _initAgentBusListener() {
    _agentBusSub = _agentBus.eventStream.listen((event) {
      if (event.type == AgentEventType.terminalCommand) {
        final command = event.payload as String?;
        if (command != null) {
          _handleRemoteCommand(command);
        }
      }
    });
  }

  Future<void> _handleRemoteCommand(String command) async {
    // If no sessions exist, create one first
    if (_sessions.isEmpty) {
      await createSession(title: 'Agent Terminal', isRoot: true);
    }
    
    // Send command to the first available bridge
    final firstId = _sessions.first.id;
    final bridge = _bridges[firstId];
    if (bridge != null) {
      bridge.write('$command\n');
    }
  }

  List<TerminalSession> get sessions => List.unmodifiable(_sessions);

  // ── ARCH DETECTION ──────────────────────────────────────────────────────────
  // Uses `uname -m` which is the canonical way on Android/Linux.
  Future<String> _getArch() async {
    try {
      final result = await Process.run('uname', ['-m']);
      final machine = result.stdout.toString().trim().toLowerCase();
      if (machine.contains('aarch64') || machine.contains('arm64')) {
        return 'arm64';
      }
      if (machine.contains('armv7') || machine.contains('armhf')) {
        return 'armhf';
      }
      if (machine.contains('x86_64') || machine.contains('amd64')) {
        return 'x86_64';
      }
      // Default fallback for most modern Android phones
      return 'arm64';
    } catch (e) {
      debugPrint('arch detection failed ($e), defaulting to arm64');
      return 'arm64';
    }
  }

  // ── DOWNLOAD URLS ───────────────────────────────────────────────────────────
  // proot-static binaries from the well-maintained proot-rs / Termux project.
  String _getPRootUrl(String arch) {
    const base =
        'https://github.com/termux/proot/releases/download/v5.3.0';
    switch (arch) {
      case 'x86_64':
        return '$base/proot-x86_64';
      case 'armhf':
        return '$base/proot-arm';
      case 'arm64':
      default:
        return '$base/proot-aarch64';
    }
  }

  String _getUbuntuUrl(String arch) {
    const base =
        'http://cdimage.ubuntu.com/ubuntu-base/releases/22.04/release';
    switch (arch) {
      case 'x86_64':
        return '$base/ubuntu-base-22.04.4-base-amd64.tar.gz';
      case 'armhf':
        return '$base/ubuntu-base-22.04.4-base-armhf.tar.gz';
      case 'arm64':
      default:
        return '$base/ubuntu-base-22.04.4-base-arm64.tar.gz';
    }
  }

  // ── FILE DOWNLOAD WITH PROGRESS ─────────────────────────────────────────────
  Future<void> _downloadFile(
    String url,
    File target,
    ProcessBridge bridge,
  ) async {
    final request = http.Request('GET', Uri.parse(url));
    // Follow redirects
    final client = http.Client();
    final response = await client.send(request);
    final contentLength = response.contentLength ?? 0;

    final output = target.openWrite();
    int received = 0;
    int lastPct = -5; // ensures first update prints

    await response.stream
        .listen(
          (List<int> chunk) {
            received += chunk.length;
            output.add(chunk);

            if (contentLength > 0) {
              final pct = ((received / contentLength) * 100).toInt();
              if (pct - lastPct >= 5 || pct == 100) {
                bridge.injectOutput(
                  '\x1b[33m  ${target.uri.pathSegments.last}: $pct%\x1b[0m\r\n',
                );
                lastPct = pct;
              }
            }
          },
          onError: (e) =>
              bridge.injectOutput('\x1b[31mDownload error: $e\x1b[0m\r\n'),
        )
        .asFuture();
    await output.flush();
    await output.close();
    client.close();
  }

  // ── UBUNTU ENVIRONMENT SETUP ─────────────────────────────────────────────────
  Future<void> _setupUbuntuEnvironment(
    ProcessBridge bridge,
    Directory docDir,
  ) async {
    if (_setupComplete) {
      // Already set up — just let the bridge launch proot directly
      return;
    }

    final arch = await _getArch();
    bridge.injectOutput(
      '\x1b[36m⚡ CPU Architecture: $arch\x1b[0m\r\n',
    );

    final prootFile = File('${docDir.path}/proot');
    final rootfsDir = Directory('${docDir.path}/ubuntu_rootfs');

    // ── 1. Download proot binary ─────────────────────────────────────────────
    if (!await prootFile.exists()) {
      bridge.injectOutput('\x1b[36m[1/3] Downloading proot binary...\x1b[0m\r\n');
      try {
        await _downloadFile(_getPRootUrl(arch), prootFile, bridge);
        await Process.run('chmod', ['+x', prootFile.path]);
        bridge.injectOutput('\x1b[32m  ✓ proot ready\x1b[0m\r\n');
      } catch (e) {
        bridge.injectOutput('\x1b[31m  ✗ proot download failed: $e\x1b[0m\r\n');
        return;
      }
    } else {
      // Ensure it's still executable (may have lost perms between app restarts)
      await Process.run('chmod', ['+x', prootFile.path]);
      bridge.injectOutput('\x1b[32m  ✓ proot cached\x1b[0m\r\n');
    }

    // ── 2. Download Ubuntu rootfs tarball ────────────────────────────────────
    final bashBin = File('${rootfsDir.path}/bin/bash');
    if (!await bashBin.exists()) {
      final tarball = File('${docDir.path}/ubuntu.tar.gz');

      if (!await tarball.exists()) {
        bridge.injectOutput(
          '\x1b[36m[2/3] Downloading Ubuntu 22.04 base ($arch)...\x1b[0m\r\n',
        );
        try {
          await _downloadFile(_getUbuntuUrl(arch), tarball, bridge);
          bridge.injectOutput('\x1b[32m  ✓ Downloaded\x1b[0m\r\n');
        } catch (e) {
          bridge.injectOutput(
            '\x1b[31m  ✗ Ubuntu download failed: $e\x1b[0m\r\n',
          );
          return;
        }
      }

      // ── 3. Extract using system tar (handles GNU long-name extensions and
      //        avoids OOM — Dart extracting 200MB in memory crashes phones)
      bridge.injectOutput(
        '\x1b[36m[3/3] Extracting Ubuntu filesystem...\x1b[0m\r\n',
      );
      await rootfsDir.create(recursive: true);

      try {
        final extractResult = await Process.run(
          'tar',
          ['-xzf', tarball.path, '-C', rootfsDir.path],
          runInShell: false,
        );
        if (extractResult.exitCode != 0) {
          bridge.injectOutput(
            '\x1b[31m  ✗ Extraction failed: ${extractResult.stderr}\x1b[0m\r\n',
          );
          return;
        }
        bridge.injectOutput('\x1b[32m  ✓ Extracted\x1b[0m\r\n');

        // Cleanup tarball to free storage
        await tarball.delete();

        // Fix permissions on critical binaries
        await Process.run(
          'chmod',
          ['+x', '${rootfsDir.path}/bin/bash', '${rootfsDir.path}/bin/sh'],
        );
      } catch (e) {
        bridge.injectOutput('\x1b[31m  ✗ Extraction error: $e\x1b[0m\r\n');
        return;
      }

      // ── 4. Configure resolv.conf (DNS) ───────────────────────────────────
      bridge.injectOutput('\x1b[36m  Configuring DNS...\x1b[0m\r\n');
      try {
        final resolvConf = File('${rootfsDir.path}/etc/resolv.conf');
        await resolvConf.writeAsString(
          'nameserver 8.8.8.8\nnameserver 1.1.1.1\n',
        );
        bridge.injectOutput('\x1b[32m  ✓ DNS configured\x1b[0m\r\n');
      } catch (_) {}

      bridge.injectOutput(
        '\x1b[32;1m\r\n🎉 Ubuntu environment ready!\x1b[0m\r\n\n',
      );
    }

    _setupComplete = true;
  }

  // ── LAUNCHER SCRIPT ──────────────────────────────────────────────────────────
  Future<void> _extractLauncher(Directory docDir) async {
    final launcherFile = File('${docDir.path}/proot_launcher.sh');
    try {
      final data = await rootBundle.load('assets/proot_launcher.sh');
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      await launcherFile.writeAsBytes(bytes, flush: true);
      await Process.run('chmod', ['+x', launcherFile.path]);
    } catch (e) {
      debugPrint('Failed extracting launcher: $e');
    }
  }

  // ── SESSION CREATION ─────────────────────────────────────────────────────────
  Future<TerminalSession> createSession({
    String? title,
    String? shell,
    bool isRoot = false,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final session = TerminalSession(
      id: id,
      title: title ?? 'Session ${_sessions.length + 1}',
      shell: shell ?? 'sh',
      isRoot: isRoot,
      lastActive: DateTime.now(),
    );

    _sessions.add(session);
    notifyListeners(); // Notify immediately so the UI shows the new tab/terminal

    final bridge = ProcessBridge();
    _bridges[id] = bridge;

    // On Android, run setup BEFORE launching the PTY process so the user sees
    // download progress. The bridge injects text directly into the xterm stream.
    if (isRoot && Platform.isAndroid) {
      bridge.injectOutput(
        '\x1b[36m⠿ Checking Ubuntu Environment...\x1b[0m\r\n',
      );
      try {
        final docDir = await getApplicationDocumentsDirectory();
        await _extractLauncher(docDir);
        await _setupUbuntuEnvironment(bridge, docDir);
      } catch (e) {
        bridge.injectOutput('\x1b[31m✗ Initialization error: $e\x1b[0m\r\n');
      }
    }

    // Now start the underlying PTY (which will launch proot or fallback shell)
    final workspacePath = await _workspaceManager.getWorkspaceRootPath();
    await bridge.launch(workspacePath: workspacePath);

    notifyListeners(); // Notify again once the process is fully launched
    return session;
  }

  // ── ACCESSORS ────────────────────────────────────────────────────────────────
  ProcessBridge? getBridge(String sessionId) => _bridges[sessionId];

  void closeSession(String sessionId) {
    _sessions.removeWhere((s) => s.id == sessionId);
    _bridges[sessionId]?.dispose();
    _bridges.remove(sessionId);
    notifyListeners();
  }

  void dispose() {
    for (var bridge in _bridges.values) {
      bridge.dispose();
    }
    _agentBusSub?.cancel();
    _bridges.clear();
    _sessions.clear();
  }
}
