import 'package:flutter/material.dart';
import 'glass_panel.dart';

class SlidingPillOption<T> {
  final T value;
  final String label;
  final IconData? icon;
  final String? badge;
  final bool showLiveDot;

  const SlidingPillOption({
    required this.value,
    required this.label,
    this.icon,
    this.badge,
    this.showLiveDot = false,
  });
}

/// Hardware-accelerated sliding tab pill indicator using Cubic(0.16, 1.0, 0.3, 1.0)
/// inside a RepaintBoundary (MOBILE_TECHSTACK.md Section 11.2).
class SlidingSegmentedPill<T> extends StatelessWidget {
  final List<SlidingPillOption<T>> options;
  final T selectedValue;
  final ValueChanged<T> onSelected;
  final double height;
  final Color activeColor;

  const SlidingSegmentedPill({
    super.key,
    required this.options,
    required this.selectedValue,
    required this.onSelected,
    this.height = 38.0,
    this.activeColor = const Color(0x28FFFFFF),
  });

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) return const SizedBox.shrink();

    final selectedIndex = options
        .indexWhere((o) => o.value == selectedValue)
        .clamp(0, options.length - 1);

    return RepaintBoundary(
      child: Container(
        height: height,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: const Color(0x73000000),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: AppThemeTokens.borderSubtle),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final segmentWidth = constraints.maxWidth / options.length;
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: AppThemeTokens.springCurve,
                  left: selectedIndex * segmentWidth,
                  top: 0,
                  bottom: 0,
                  width: segmentWidth,
                  child: Container(
                    decoration: BoxDecoration(
                      color: activeColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppThemeTokens.borderStrong),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (final opt in options)
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onSelected(opt.value),
                          child: Center(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (opt.icon != null) ...[
                                    Icon(
                                      opt.icon,
                                      size: 14,
                                      color: opt.value == selectedValue
                                          ? AppThemeTokens.textPrimary
                                          : AppThemeTokens.textSecondary,
                                    ),
                                    const SizedBox(width: 5),
                                  ],
                                  Flexible(
                                    child: Text(
                                      opt.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: opt.value == selectedValue
                                            ? FontWeight.w700
                                            : FontWeight.w600,
                                        color: opt.value == selectedValue
                                            ? AppThemeTokens.textPrimary
                                            : AppThemeTokens.textSecondary,
                                      ),
                                    ),
                                  ),
                                  if (opt.badge != null) ...[
                                    const SizedBox(width: 5),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: opt.value == selectedValue
                                            ? const Color(0x2800E676)
                                            : const Color(0x1FFFFFFF),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        opt.badge!,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: opt.value == selectedValue
                                              ? AppThemeTokens.accentGreen
                                              : AppThemeTokens.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (opt.showLiveDot) ...[
                                    const SizedBox(width: 5),
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: AppThemeTokens.accentGreen,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
