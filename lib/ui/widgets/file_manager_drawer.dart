import 'package:flutter/material.dart';

class FileManagerDrawer extends StatelessWidget {
  const FileManagerDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF252526),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'EXPLORER',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                   _buildFolder('lib', isExpanded: true, children: [
                    _buildFile('main.dart', isDart: true),
                    _buildFolder('ui', isExpanded: true, children: [
                      _buildFile('router.dart', isDart: true),
                    ]),
                  ]),
                  _buildFolder('assets', isExpanded: false, children: []),
                  _buildFile('pubspec.yaml', isConfig: true),
                  _buildFile('README.md'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFolder(String name, {required bool isExpanded, required List<Widget> children}) {
    return ExpansionTile(
      initiallyExpanded: isExpanded,
      iconColor: Colors.grey,
      collapsedIconColor: Colors.grey,
      title: Row(
        children: [
          Icon(isExpanded ? Icons.folder_open : Icons.folder, size: 16, color: Colors.blueAccent),
          const SizedBox(width: 8),
          Text(name, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        ],
      ),
      childrenPadding: const EdgeInsets.only(left: 16),
      children: children,
    );
  }

  Widget _buildFile(String name, {bool isDart = false, bool isConfig = false}) {
    IconData iconData = Icons.insert_drive_file;
    Color iconColor = Colors.grey;
    
    if (isDart) {
      iconData = Icons.code;
      iconColor = Colors.tealAccent;
    } else if (isConfig) {
      iconData = Icons.settings;
      iconColor = Colors.orangeAccent;
    }

    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: Icon(iconData, size: 16, color: iconColor),
      title: Text(name, style: const TextStyle(color: Colors.white70, fontSize: 14)),
      onTap: () {},
    );
  }
}
