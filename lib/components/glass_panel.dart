import 'dart:ui';
import 'package:flutter/material.dart';

/// Shared design tokens matching MusicBotUI DESIGN.md and MOBILE_TECHSTACK.md Section 11.
abstract final class AppThemeTokens {
  static const Color bgPrimary = Color(0xFF0F172A);
  static const Color bgDeep = Color(0xFF0B1014);
  static const Color bgElevated = Color(0xFF1E293B);
  static const Color bgSurface = Color(0xCC12191F);
  static const Color bgInput = Color(0x990C1116);

  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  static const Color accentGreen = Color(0xFF00E676);
  static const Color accentEmerald = Color(0xFF10B981);
  static const Color accentIndigo = Color(0xFF6366F1);
  static const Color accentPurple = Color(0xFFA855F7);
  static const Color accentSky = Color(0xFF38BDF8);
  static const Color accentAmber = Color(0xFFF59E0B);
  static const Color accentRose = Color(0xFFF43F5E);

  static const Color borderSubtle = Color(0x16FFFFFF);
  static const Color borderStrong = Color(0x28FFFFFF);

  static const Curve springCurve = Cubic(0.16, 1.0, 0.3, 1.0);

  /// Formats seconds into `m:ss` or `h:mm:ss`.
  static String formatDuration(num? seconds) {
    if (seconds == null || seconds.isNaN || seconds.isInfinite || seconds < 0) {
      return '0:00';
    }
    final total = seconds.floor();
    final hrs = total ~/ 3600;
    final mins = (total % 3600) ~/ 60;
    final secs = total % 60;
    final secStr = secs.toString().padLeft(2, '0');
    if (hrs > 0) {
      final minStr = mins.toString().padLeft(2, '0');
      return '$hrs:$minStr:$secStr';
    }
    return '$mins:$secStr';
  }
}

/// Reusable dark glassmorphic container matching MusicBotUI's `.glass-panel` styling.
class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
  final bool enableBlur;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 22.0,
    this.backgroundColor,
    this.borderColor,
    this.enableBlur = false,
  });

  @override
  Widget build(BuildContext context) {
    final container = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppThemeTokens.bgSurface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? AppThemeTokens.borderSubtle,
          width: 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x45000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );

    if (!enableBlur) return container;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: container,
      ),
    );
  }
}
