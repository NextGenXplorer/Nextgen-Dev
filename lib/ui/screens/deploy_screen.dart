import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/app_drawer.dart';
import '../../application/providers/deploy_service_provider.dart';
import '../../application/providers/agent_session_provider.dart';
import '../../infrastructure/services/deploy_service.dart';
import '../themes.dart';

// ── Platform selection state ─────────────────────────────────────────────────
enum DeployTarget { netlify, vercel, github }

final _deployTargetProvider = StateProvider<DeployTarget?>((ref) => null);

// ── Screen ───────────────────────────────────────────────────────────────────
class DeployScreen extends ConsumerWidget {
  const DeployScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deployService = ref.watch(deployServiceProvider);
    final selectedTarget = ref.watch(_deployTargetProvider);

    return Scaffold(
      backgroundColor: AppThemes.bgDark,
      drawer: const AppDrawer(currentConversationId: null),
      body: Stack(
        children: [
          // Premium background
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topRight,
                  radius: 1.5,
                  colors: [
                    AppThemes.accentCyan.withOpacity(0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Platform Picker ──────────────────────────────
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Text(
                            'SELECT PLATFORM',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              color: AppThemes.textSecondary,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            _PlatformCard(
                              label: 'Netlify',
                              icon: Icons.cloud_queue_rounded,
                              color: const Color(0xFF00AD9F),
                              selected: selectedTarget == DeployTarget.netlify,
                              onTap: () => ref.read(_deployTargetProvider.notifier).state =
                                  DeployTarget.netlify,
                            ),
                            const SizedBox(width: 12),
                            _PlatformCard(
                              label: 'Vercel',
                              icon: Icons.bolt_rounded,
                              color: Colors.white,
                              selected: selectedTarget == DeployTarget.vercel,
                              onTap: () => ref.read(_deployTargetProvider.notifier).state =
                                  DeployTarget.vercel,
                            ),
                            const SizedBox(width: 12),
                            _PlatformCard(
                              label: 'GitHub',
                              icon: Icons.commit_rounded,
                              color: const Color(0xFF6E40C9),
                              selected: selectedTarget == DeployTarget.github,
                              onTap: () => ref.read(_deployTargetProvider.notifier).state =
                                  DeployTarget.github,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // ── Active project info ──────────────────────────
                        _buildActiveProjectCard(ref),
                        const SizedBox(height: 24),

                        // ── Status card ──────────────────────────────────
                        _buildMainStatusCard(deployService),
                        const SizedBox(height: 24),
                        _buildStepTracker(deployService.status),
                        const SizedBox(height: 24),
                        _buildLogViewer(deployService.logs),
                      ],
                    ),
                  ),
                ),
                _buildFooterActions(context, ref, deployService, selectedTarget),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveProjectCard(WidgetRef ref) {
    final session = ref.watch(agentSessionProvider);
    final projectPath = session.activeProjectPath;
    if (projectPath == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppThemes.surfaceDark.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppThemes.accentCyan.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.folder_rounded, color: AppThemes.accentCyan, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              projectPath,
              style: const TextStyle(
                color: AppThemes.textSecondary,
                fontSize: 12,
                fontFamily: 'JetBrainsMono',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppThemes.dividerColor, width: 0.5)),
      ),
      child: Row(
        children: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu_rounded, color: AppThemes.textSecondary),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'DEPLOYMENT COMMAND',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              color: AppThemes.textPrimary,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppThemes.accentCyan.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppThemes.accentCyan.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_rounded, size: 12, color: AppThemes.accentCyan),
                SizedBox(width: 4),
                Text('ENCRYPTED',
                    style: TextStyle(fontSize: 10, color: AppThemes.accentCyan, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainStatusCard(DeployService service) {
    final statusColor = _getStatusColor(service.status);
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppThemes.surfaceDark.withOpacity(0.6),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: statusColor.withOpacity(0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: statusColor.withOpacity(0.1),
                blurRadius: 40,
                spreadRadius: -10,
              ),
            ],
          ),
          child: Column(
            children: [
              _buildLargeStatusIcon(service.status),
              const SizedBox(height: 20),
              Text(
                service.status.name.toUpperCase(),
                style: TextStyle(
                  color: statusColor,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                service.message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppThemes.textSecondary, fontSize: 15),
              ),
              if (service.status != DeployStatus.idle) ...[
                const SizedBox(height: 24),
                LinearProgressIndicator(
                  value: service.progress,
                  backgroundColor: Colors.white10,
                  color: statusColor,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(5),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(service.progress * 100).toInt()}%',
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLargeStatusIcon(DeployStatus status) {
    IconData icon;
    switch (status) {
      case DeployStatus.idle:       icon = Icons.cloud_upload_outlined; break;
      case DeployStatus.building:   icon = Icons.auto_fix_high_rounded; break;
      case DeployStatus.deploying:  icon = Icons.rocket_launch_rounded; break;
      case DeployStatus.success:    icon = Icons.verified_rounded; break;
      case DeployStatus.failure:    icon = Icons.gpp_bad_rounded; break;
    }
    return Icon(icon, size: 64, color: _getStatusColor(status));
  }

  Widget _buildStepTracker(DeployStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        color: AppThemes.surfaceDark.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppThemes.dividerColor, width: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStepItem('BUILD',
              status == DeployStatus.building ||
              status == DeployStatus.deploying ||
              status == DeployStatus.success),
          _buildStepDivider(),
          _buildStepItem('TEST', status == DeployStatus.deploying || status == DeployStatus.success),
          _buildStepDivider(),
          _buildStepItem('DEPLOY', status == DeployStatus.success),
        ],
      ),
    );
  }

  Widget _buildStepItem(String label, bool active) => Column(
    children: [
      Icon(
        active ? Icons.check_circle_rounded : Icons.circle_outlined,
        size: 18,
        color: active ? AppThemes.accentGreen : AppThemes.textSecondary.withOpacity(0.3),
      ),
      const SizedBox(height: 4),
      Text(label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: active ? AppThemes.textPrimary : AppThemes.textSecondary.withOpacity(0.3),
          )),
    ],
  );

  Widget _buildStepDivider() =>
      Container(width: 40, height: 1, color: AppThemes.dividerColor);

  Widget _buildLogViewer(List<String> logs) {
    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppThemes.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF161B22),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: const Row(
              children: [
                Icon(Icons.terminal_rounded, size: 14, color: AppThemes.textSecondary),
                SizedBox(width: 8),
                Text('DEPLOY_LOGS',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppThemes.textSecondary)),
              ],
            ),
          ),
          Expanded(
            child: logs.isEmpty
                ? const Center(
                    child: Text('Waiting for deployment logs...',
                        style: TextStyle(color: Colors.white10, fontSize: 12)))
                : ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: logs.length,
                    itemBuilder: (_, i) => Text(
                      logs[i],
                      style: const TextStyle(
                        color: AppThemes.accentGreen,
                        fontFamily: 'JetBrainsMono',
                        fontSize: 11,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterActions(BuildContext context, WidgetRef ref,
      DeployService service, DeployTarget? target) {
    final canStart = service.status == DeployStatus.idle ||
        service.status == DeployStatus.success ||
        service.status == DeployStatus.failure;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppThemes.bgDark,
        border: const Border(top: BorderSide(color: AppThemes.dividerColor, width: 0.5)),
      ),
      child: !canStart
          ? const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppThemes.accentCyan)),
                SizedBox(width: 12),
                Text('DEPLOYMENT IN PROGRESS...',
                    style: TextStyle(color: AppThemes.textSecondary, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.commit_rounded, size: 18),
                    label: const Text('Push to GitHub'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6E40C9),
                      side: const BorderSide(color: Color(0xFF6E40C9)),
                      minimumSize: const Size(0, 52),
                    ),
                    onPressed: () => _onGitHubPush(ref),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(
                      target == DeployTarget.netlify
                          ? Icons.cloud_queue_rounded
                          : Icons.bolt_rounded,
                      size: 18,
                    ),
                    label: Text(target == null
                        ? 'Select Platform'
                        : 'Deploy to ${target.name[0].toUpperCase()}${target.name.substring(1)}'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: target == null
                          ? AppThemes.textSecondary.withOpacity(0.3)
                          : AppThemes.accentCyan,
                      foregroundColor: AppThemes.bgDark,
                      minimumSize: const Size(0, 52),
                    ),
                    onPressed: target == null ? null : () => _onDeploy(ref, target, service),
                  ),
                ),
              ],
            ),
    );
  }

  // ── Actions ──────────────────────────────────────────────────────────────
  Future<void> _onGitHubPush(WidgetRef ref) async {
    final url = Uri.parse('https://github.com/new');
    if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Future<void> _onDeploy(WidgetRef ref, DeployTarget target, DeployService service) async {
    if (target == DeployTarget.netlify) {
      final url = Uri.parse('https://app.netlify.com/drop');
      if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
    } else if (target == DeployTarget.vercel) {
      final url = Uri.parse('https://vercel.com/new');
      if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
    } else if (target == DeployTarget.github) {
      _onGitHubPush(ref);
    }
  }

  Color _getStatusColor(DeployStatus status) {
    switch (status) {
      case DeployStatus.idle:      return AppThemes.textSecondary;
      case DeployStatus.building:  return AppThemes.accentGold;
      case DeployStatus.deploying: return AppThemes.accentCyan;
      case DeployStatus.success:   return AppThemes.accentGreen;
      case DeployStatus.failure:   return AppThemes.errorRed;
    }
  }
}

// ── Platform Card widget ──────────────────────────────────────────────────────
class _PlatformCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _PlatformCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.15) : AppThemes.surfaceDark.withOpacity(0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? color : AppThemes.dividerColor,
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? [BoxShadow(color: color.withOpacity(0.25), blurRadius: 16, spreadRadius: -4)]
                : [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 30, color: selected ? color : AppThemes.textSecondary),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: selected ? color : AppThemes.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
