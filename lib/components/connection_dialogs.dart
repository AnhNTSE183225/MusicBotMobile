import 'package:flutter/material.dart';
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

class AuthConfigDialog extends StatefulWidget {
  final AuthStore authStore;
  final VoidCallback onAuthenticated;

  const AuthConfigDialog({
    super.key,
    required this.authStore,
    required this.onAuthenticated,
  });

  @override
  State<AuthConfigDialog> createState() => _AuthConfigDialogState();
}

class _AuthConfigDialogState extends State<AuthConfigDialog> {
  late final TextEditingController _serverController;
  late final TextEditingController _tokenController;

  @override
  void initState() {
    super.initState();
    _serverController =
        TextEditingController(text: widget.authStore.serverBaseUrl.value);
    _tokenController = TextEditingController();
  }

  @override
  void dispose() {
    _serverController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authStore = widget.authStore;

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
                      Icons.security_rounded,
                      color: AppThemeTokens.accentGreen,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Discord Session & Server',
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
                  'BACKEND API URL',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppThemeTokens.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _serverController,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppThemeTokens.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'https://theanh.tail38dac5.ts.net/api',
                    filled: true,
                    fillColor: AppThemeTokens.bgInput,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppThemeTokens.borderSubtle),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    await authStore
                        .updateServerBaseUrl(_serverController.text);
                    await launchUrl(
                      Uri.parse(authStore.loginUrl),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5865F2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                  label: const Text(
                    'Open Discord OAuth2 in Browser',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'SESSION TOKEN (FROM OAUTH REDIRECT OR WEB APP)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppThemeTokens.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _tokenController,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppThemeTokens.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Paste ?token=... session token here',
                    filled: true,
                    fillColor: AppThemeTokens.bgInput,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppThemeTokens.borderSubtle),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: () async {
                    await authStore
                        .updateServerBaseUrl(_serverController.text);
                    if (_tokenController.text.trim().isNotEmpty) {
                      final ok =
                          await authStore.loginWithToken(_tokenController.text);
                      if (ok && context.mounted) {
                        widget.onAuthenticated();
                        Navigator.of(context).pop();
                      }
                    } else if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppThemeTokens.accentGreen,
                    foregroundColor: AppThemeTokens.bgDeep,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Save & Connect',
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
