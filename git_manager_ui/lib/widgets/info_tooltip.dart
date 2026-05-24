import 'package:flutter/material.dart';
import '../theme.dart';

/// Botão (i) que explica o que um comando Git faz.
/// Ideal para usuários leigos entenderem a interface.
class InfoTooltip extends StatelessWidget {
  final String message;
  final double size;

  const InfoTooltip({
    super.key,
    required this.message,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: message,
      waitDuration: const Duration(milliseconds: 200),
      showDuration: const Duration(seconds: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.bgElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderStrong),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      textStyle: const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 12,
        height: 1.4,
      ),
      child: MouseRegion(
        cursor: SystemMouseCursors.help,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppTheme.accent.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4), width: 1),
          ),
          child: Center(
            child: Text(
              'i',
              style: TextStyle(
                color: AppTheme.accent,
                fontSize: size * 0.6,
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
