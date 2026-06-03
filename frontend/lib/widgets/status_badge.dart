import 'package:flutter/material.dart';
import '../theme.dart';
import '../utils/responsive.dart';

/// Minimalista indicador de status — apenas um dot com tooltip.
/// Remove completamente o badge de texto "alteração" amarelo.
class StatusBadge extends StatelessWidget {
  final bool isOk;
  final bool isError;
  final double scale;
  final String? tooltip;

  const StatusBadge({
    super.key,
    this.isOk = false,
    this.isError = false,
    this.scale = 1.0,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final color = isError
        ? AppTheme.danger
        : isOk
            ? AppTheme.success
            : AppTheme.warning;

    final size = Responsive.icon(8, scale);

    Widget dot = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.5),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      dot = Tooltip(
        message: tooltip!,
        waitDuration: const Duration(milliseconds: 300),
        child: dot,
      );
    }

    return dot;
  }

  factory StatusBadge.ok({double scale = 1.0}) => StatusBadge(
        isOk: true,
        scale: scale,
        tooltip: 'OK',
      );

  factory StatusBadge.error({double scale = 1.0, String? tooltip}) => StatusBadge(
        isError: true,
        scale: scale,
        tooltip: tooltip ?? 'Error',
      );

  factory StatusBadge.warn({double scale = 1.0, String? tooltip}) => StatusBadge(
        isError: false,
        isOk: false,
        scale: scale,
        tooltip: tooltip ?? 'Warning',
      );
}
