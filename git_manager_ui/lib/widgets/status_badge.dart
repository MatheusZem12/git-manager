import 'package:flutter/material.dart';
import '../theme.dart';

class StatusBadge extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.text,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  factory StatusBadge.ok({String text = 'OK'}) => StatusBadge(
        text: text,
        color: AppTheme.success,
        icon: Icons.check_circle_rounded,
      );

  factory StatusBadge.warn(String text) => StatusBadge(
        text: text,
        color: AppTheme.warning,
        icon: Icons.warning_amber_rounded,
      );

  factory StatusBadge.error(String text) => StatusBadge(
        text: text,
        color: AppTheme.danger,
        icon: Icons.error_outline,
      );

  factory StatusBadge.neutral(String text) => StatusBadge(
        text: text,
        color: AppTheme.textMuted,
      );
}
