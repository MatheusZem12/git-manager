import 'package:flutter/material.dart';
import '../theme.dart';
import '../utils/responsive.dart';

enum ModernButtonVariant {
  primary,
  success,
  danger,
  warning,
  info,
  neutral,
  ghost,
}

class ModernButton extends StatefulWidget {
  final String? label;
  final IconData? icon;
  final VoidCallback onPressed;
  final ModernButtonVariant variant;
  final double scale;
  final bool compact;
  final bool tiny;
  final String? tooltip;
  final bool disabled;

  const ModernButton({
    super.key,
    this.label,
    this.icon,
    required this.onPressed,
    this.variant = ModernButtonVariant.primary,
    this.scale = 1.0,
    this.compact = false,
    this.tiny = false,
    this.tooltip,
    this.disabled = false,
  });

  @override
  State<ModernButton> createState() => _ModernButtonState();
}

class _ModernButtonState extends State<ModernButton> {
  bool _hover = false;
  bool _pressed = false;

  Color get _baseColor {
    return switch (widget.variant) {
      ModernButtonVariant.primary => AppTheme.accent,
      ModernButtonVariant.success => AppTheme.success,
      ModernButtonVariant.danger => AppTheme.danger,
      ModernButtonVariant.warning => AppTheme.warning,
      ModernButtonVariant.info => AppTheme.info,
      ModernButtonVariant.neutral => AppTheme.textMuted,
      ModernButtonVariant.ghost => AppTheme.textSecondary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.scale;
    final hasLabel = widget.label != null && widget.label!.isNotEmpty;
    final hasIcon = widget.icon != null;
    final isGhost = widget.variant == ModernButtonVariant.ghost;

    final hPad = widget.tiny
        ? Responsive.pad(6, s)
        : widget.compact
            ? Responsive.pad(8, s)
            : Responsive.pad(14, s);
    final vPad = widget.tiny
        ? Responsive.pad(4, s)
        : widget.compact
            ? Responsive.pad(5, s)
            : Responsive.pad(9, s);
    final iconSize = widget.tiny
        ? Responsive.icon(13, s)
        : widget.compact
            ? Responsive.icon(15, s)
            : Responsive.icon(16, s);
    final fontSize = widget.tiny
        ? Responsive.font(11, s)
        : widget.compact
            ? Responsive.font(12, s)
            : Responsive.font(13, s);

    final effectiveOpacity = widget.disabled ? 0.35 : 1.0;
    final effectiveHover = widget.disabled ? false : _hover;
    final effectivePressed = widget.disabled ? false : _pressed;

    Widget btn = MouseRegion(
      cursor: widget.disabled ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
      onEnter: (_) {
        if (!widget.disabled) setState(() => _hover = true);
      },
      onExit: (_) {
        if (!widget.disabled) setState(() => _hover = false);
      },
      child: GestureDetector(
        onTapDown: (_) {
          if (!widget.disabled) setState(() => _pressed = true);
        },
        onTapUp: (_) {
          if (!widget.disabled) setState(() => _pressed = false);
        },
        onTapCancel: () {
          if (!widget.disabled) setState(() => _pressed = false);
        },
        onTap: widget.disabled ? () {} : widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
          decoration: BoxDecoration(
            color: isGhost
                ? (effectiveHover ? _baseColor.withValues(alpha: 0.1) : Colors.transparent)
                : _baseColor.withValues(alpha: effectiveHover ? 0.9 : 0.75),
            borderRadius: BorderRadius.circular(Responsive.pad(8, s)),
            boxShadow: isGhost || _pressed
                ? []
                : [
                    BoxShadow(
                      color: _baseColor.withValues(alpha: effectiveHover ? 0.25 : 0.15),
                      blurRadius: effectiveHover ? 10 : 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
            border: Border.all(
              color: isGhost
                  ? (effectiveHover ? _baseColor.withValues(alpha: 0.5) : AppTheme.borderStrong.withValues(alpha: 0.3))
                  : _baseColor.withValues(alpha: 0.6),
              width: 1,
            ),
          ),
          transform: Matrix4.identity()..scale(effectivePressed ? 0.96 : 1.0),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasIcon) ...[
                Icon(
                  widget.icon,
                  size: iconSize,
                  color: isGhost ? _baseColor : Colors.white,
                ),
                if (hasLabel) SizedBox(width: Responsive.pad(6, s)),
              ],
              if (hasLabel)
                Text(
                  widget.label!,
                  style: TextStyle(
                    color: isGhost ? _baseColor : Colors.white,
                    fontSize: fontSize,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (widget.tooltip != null && widget.tooltip!.isNotEmpty) {
      btn = Tooltip(
        message: widget.tooltip!,
        waitDuration: const Duration(milliseconds: 200),
        showDuration: Duration.zero,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.bgElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.borderStrong),
        ),
        textStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        child: btn,
      );
    }

    return Opacity(
      opacity: effectiveOpacity,
      child: IntrinsicWidth(child: btn),
    );
  }
}
