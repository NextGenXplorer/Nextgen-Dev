import 'dart:convert';
import 'dart:io';
import 'agent_tool.dart';

class ScreenshotTool implements AgentTool {
  @override
  String get name => 'take_screenshot';

  @override
  String get displayName => 'Screenshot';

  @override
  String get uiIcon => 'image';

  @override
  String get description =>
      'Takes a screenshot of the connected Android device/emulator. Returns base64 PNG data. Use this to visually verify UI changes.';

  @override
  Future<String> execute(Map<String, dynamic> params) async {
    try {
      // Use stdoutEncoding: null to get raw bytes for the PNG image
      final result = await Process.run(
        'adb', 
        ['exec-out', 'screencap', '-p'],
        stdoutEncoding: null,
      );

      if (result.exitCode == 0) {
        final bytes = result.stdout as List<int>;
        return base64Encode(bytes);
      } else {
        return 'Error taking screenshot: ${result.stderr}';
      }
    } catch (e) {
      return 'Error taking screenshot: $e';
    }
  }
}
