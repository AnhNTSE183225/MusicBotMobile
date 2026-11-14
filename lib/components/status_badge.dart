import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';
import '../models/state_machine_dto.dart';
import 'glass_panel.dart';

/// Leaf-reactive StatusBadge accepting only a segregated ReadonlySignal<EntityStatus>
/// (ISP + RepaintBoundary per MOBILE_TECHSTACK.md Section 9.1).
class StatusBadge extends StatelessWidget {
  final ReadonlySignal<EntityStatus> statusSignal;

  const StatusBadge({
    super.key,
    required this.statusSignal,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Watch((context) {
        final status = statusSignal.value;
        final (label, color) = switch (status) {
          EntityStatus.active => ('PLAYING', AppThemeTokens.accentGreen),
          EntityStatus.paused => ('PAUSED', AppThemeTokens.accentAmber),
          EntityStatus.loading => ('SYNCING', AppThemeTokens.accentSky),
          EntityStatus.error => ('FAULT', AppThemeTokens.accentRose),
          EntityStatus.idle => ('STANDBY', AppThemeTokens.textSecondary),
          EntityStatus.disconnected => ('OFFLINE', AppThemeTokens.textMuted),
        };

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: status == EntityStatus.active
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.7),
                            blurRadius: 6,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: color,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
