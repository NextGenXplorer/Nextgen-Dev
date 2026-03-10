import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';
import '../../domain/models/terminal_session.dart';
import 'process_bridge.dart';

class TerminalService {
  final List<TerminalSession> _sessions = [];
  final Map<String, ProcessBridge> _bridges = {};
  
  List<TerminalSession> get sessions => List.unmodifiable(_sessions);
  
  String _getArch() {
    final arch = ProcessInfo.currentRss > 0 ? 'arm64' : 'arm'; // Very primitive fallback
    // A better way is to use Platform.version or a package, but we'll try to be smart
    if (Platform.version.toLowerCase().contains('x64')) return 'x86_64';
    if (Platform.version.toLowerCase().contains('arm64')) return 'arm64';
    return 'armhf';
  }

  String _getPRootUrl(String arch) {
    switch (arch) {
      case 'x86_64': return 'https://github.com/theshoqanebi/static-proot-x86_64/releases/download/v1.0/proot';
      case 'arm64': return 'https://github.com/theshoqanebi/static-proot-arm/releases/download/arm-build/proot';
      default: return 'https://github.com/theshoqanebi/static-proot-arm/releases/download/arm-build/proot'; 
    }
  }

  String _getUbuntuUrl(String arch) {
    switch (arch) {
      case 'x86_64': return 'http://cdimage.ubuntu.com/ubuntu-base/releases/22.04/release/ubuntu-base-22.04.4-base-amd64.tar.gz';
      case 'arm64': return 'http://cdimage.ubuntu.com/ubuntu-base/releases/22.04/release/ubuntu-base-22.04.4-base-arm64.tar.gz';
      default: return 'http://cdimage.ubuntu.com/ubuntu-base/releases/22.04/release/ubuntu-base-22.04.4-base-armhf.tar.gz';
    }
  }

  Future<void> _downloadFile(String url, File target, ProcessBridge bridge) async {
    final request = http.Request('GET', Uri.parse(url));
    final response = await http.Client().send(request);
    final contentLength = response.contentLength ?? 0;
    
    final output = target.openWrite();
    int received = 0;
    int lastPercentage = 0;

    await response.stream.listen(
      (List<int> chunk) {
        received += chunk.length;
        output.add(chunk);
        
        if (contentLength > 0) {
          final percentage = ((received / contentLength) * 100).toInt();
          // Print progress every 5%
          if (percentage - lastPercentage >= 5 || percentage == 100) {
            bridge.injectOutput('\x1b[33mDownloading ${target.uri.pathSegments.last}... $percentage%\x1b[0m\r\n');
            lastPercentage = percentage;
          }
        }
      },
      onDone: () {},
      onError: (e) {
        bridge.injectOutput('\x1b[31mDownload failed: $e\x1b[0m\r\n');
      },
    ).asFuture();
    await output.close();
  }

  Future<void> _setupUbuntuEnvironment(ProcessBridge bridge, Directory docDir) async {
    final arch = _getArch();
    final prootFile = File('${docDir.path}/proot');
    final rootfsDir = Directory('${docDir.path}/ubuntu_rootfs');
    
    final prootUrl = _getPRootUrl(arch);
    final ubuntuUrl = _getUbuntuUrl(arch);

    // 1. Download PRoot
    if (!await prootFile.exists()) {
      bridge.injectOutput('\x1b[36m[1/3] Detected CPU: $arch. Downloading PRoot binary...\x1b[0m\r\n');
      await _downloadFile(prootUrl, prootFile, bridge);
      if (!Platform.isWindows) {
        await Process.run('chmod', ['+x', prootFile.path]);
      }
    }

    // 2. Download and Extract Ubuntu RootFS
    final bashPath = File('${rootfsDir.path}/bin/bash');
    if (!await bashPath.exists()) {
      final tarballData = File('${docDir.path}/ubuntu.tar.gz');
      
      bridge.injectOutput('\x1b[36m[2/3] Downloading Ubuntu Base System...\x1b[0m\r\n');
      await _downloadFile(ubuntuUrl, tarballData, bridge);

      bridge.injectOutput('\x1b[36m[3/3] Extracting Ubuntu Filesystem... (This might take a moment)\x1b[0m\r\n');
      final bytes = await tarballData.readAsBytes();
      
      // We do this in an isolate normally, but keeping simple for now
      final archive = TarDecoder().decodeBytes(GZipDecoder().decodeBytes(bytes));
      
      for (final file in archive) {
        final filename = '${rootfsDir.path}/${file.name}';
        if (file.isFile) {
          final outFile = File(filename);
          await outFile.create(recursive: true);
          await outFile.writeAsBytes(file.content as List<int>);
        } else {
          await Directory(filename).create(recursive: true);
        }
      }
      
      // Cleanup tarball
      await tarballData.delete();

      // Configure networking seamlessly
      bridge.injectOutput('\x1b[36mConfiguring Network DNS...\x1b[0m\r\n');
      final resolvConf = File('${rootfsDir.path}/etc/resolv.conf');
      await resolvConf.writeAsString('nameserver 8.8.8.8\nnameserver 1.1.1.1\n');
      
      bridge.injectOutput('\x1b[32mEnvironment successfully initialized!\x1b[0m\r\n\n');
    }
  }

  Future<void> _extractLauncher(Directory docDir) async {
    final launcherFile = File('${docDir.path}/proot_launcher.sh');
    try {
      final data = await rootBundle.load('assets/proot_launcher.sh');
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await launcherFile.writeAsBytes(bytes);
      if (!Platform.isWindows) {
        await Process.run('chmod', ['+x', launcherFile.path]);
      }
    } catch (e) {
      debugPrint('Skipped extracting launcher asset: $e');
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

    if (isRoot && Platform.isAndroid) {
      // Begin dynamic PRoot bootstrapping if needed
      bridge.injectOutput('\x1b[36mChecking Ubuntu Environment...\x1b[0m\r\n');
      try {
        final docDir = await getApplicationDocumentsDirectory();
        await _extractLauncher(docDir);
        await _setupUbuntuEnvironment(bridge, docDir);
      } catch (e) {
        bridge.injectOutput('\x1b[31mInitialization Error: $e\x1b[0m\r\n');
      }
    }

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
