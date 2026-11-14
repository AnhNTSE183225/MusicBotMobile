import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../stores/auth_store.dart';
import 'glass_panel.dart';

/// Connection Guide, Community Contribution, and Server/Token Login Dialogs.
class ConnectionGuideDialog extends StatelessWidget {
  final VoidCallback onSummonBot;

  const ConnectionGuideDialog({
    super.key,
    required this.onSummonBot,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: GlassPanel(
          backgroundColor: const Color(0xF511171D),
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.headset_mic_rounded,
                      color: AppThemeTokens.accentGreen,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Quick Connection Guide',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppThemeTokens.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppThemeTokens.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const _GuideStepCard(
                  number: '1',
                  title: 'Join a Discord Voice Channel',
                  description:
                      'Open Discord and connect to any voice channel in a server shared with Music Bot.',
                ),
                const SizedBox(height: 10),
                const _GuideStepCard(
                  number: '2',
                  title: 'Summon the Bot',
                  description:
                      'Tap "Summon Bot" in the header or below so the bot joins your active voice room.',
                ),
                const SizedBox(height: 10),
                const _GuideStepCard(
                  number: '3',
                  title: 'Queue Music or Use AI',
                  description:
                      'Paste a YouTube URL, import a playlist range, or let Gemini AI curate tracks.',
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onSummonBot();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppThemeTokens.accentGreen,
                    foregroundColor: AppThemeTokens.bgDeep,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.bolt_rounded, size: 18),
                  label: const Text(
                    'Summon Bot Now',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GuideStepCard extends StatelessWidget {
  final String number;
  final String title;
  final String description;

  const _GuideStepCard({
    required this.number,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppThemeTokens.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppThemeTokens.accentGreen.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppThemeTokens.accentGreen,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppThemeTokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppThemeTokens.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ContributeDialog extends StatelessWidget {
  final VoidCallback onOpenKeyPool;

  const ContributeDialog({
    super.key,
    required this.onOpenKeyPool,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: GlassPanel(
          backgroundColor: const Color(0xF511171D),
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.favorite_rounded,
                      color: AppThemeTokens.accentRose,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Contribute to Music Bot',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppThemeTokens.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppThemeTokens.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Help keep the music flowing! Contribute code on GitHub or donate a free-tier Gemini API key to expand AI recommendations for the whole server.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppThemeTokens.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () {
                    launchUrl(
                      Uri.parse('https://github.com/trantheanh1303/MusicBot'),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppThemeTokens.textPrimary,
                    side: const BorderSide(color: AppThemeTokens.borderStrong),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.code_rounded, size: 18),
                  label: const Text(
                    'GitHub Source Code & Issues',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onOpenKeyPool();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppThemeTokens.accentIndigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.vpn_key_rounded, size: 18),
                  label: const Text(
                    'Contribute Free Gemini API Key',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AuthConfigDialog extends StatelessWidget {
  final AuthStore authStore;
  final VoidCallback onAuthenticated;

  const AuthConfigDialog({
    super.key,
    required this.authStore,
    required this.onAuthenticated,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: GlassPanel(
          backgroundColor: const Color(0xF511171D),
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Watch((context) {
              final user = authStore.currentUser.value;
              final isWaiting = authStore.isWaitingForOAuth.value;
              final isAuthenticated = authStore.isAuthenticated.value;

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.security_rounded,
                        color: AppThemeTokens.accentGreen,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Discord Authentication',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppThemeTokens.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          authStore.cancelMobileDiscordLogin();
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppThemeTokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Connect with your Discord account to join voice channels, control music playback, and access server schedules.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppThemeTokens.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (isAuthenticated && user != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppThemeTokens.accentGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppThemeTokens.accentGreen.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.verified_user_rounded,
                            color: AppThemeTokens.accentGreen,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Signed in as @${user.username}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: AppThemeTokens.textPrimary,
                                  ),
                                ),
                                const Text(
                                  'Active Discord session connected',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppThemeTokens.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              await authStore.logout();
                            },
                            child: const Text(
                              'Log Out',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppThemeTokens.accentRose,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (isWaiting) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5865F2).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF5865F2).withValues(alpha: 0.45),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Row(
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Color(0xFF5865F2),
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Waiting for Discord authorization in app or browser...',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppThemeTokens.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: authStore.cancelMobileDiscordLogin,
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppThemeTokens.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    ElevatedButton.icon(
                      onPressed: () async {
                        await authStore.startMobileDiscordLogin(
                          onAuthenticated: () {
                            onAuthenticated();
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                          },
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5865F2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.discord_rounded, size: 20),
                      label: Text(
                        isAuthenticated
                            ? 'Switch Discord Account'
                            : 'Continue with Discord',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}
