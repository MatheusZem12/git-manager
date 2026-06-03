import 'package:flutter/material.dart';
import '../theme.dart';
import 'modern_button.dart';

/// Dialog de confirmação moderno e elegante.
class ModernConfirmDialog extends StatelessWidget {
  final String title;
  final Widget? content;
  final String? message;
  final String confirmLabel;
  final String cancelLabel;
  final ModernButtonVariant confirmVariant;
  final VoidCallback onConfirm;
  final VoidCallback? onCancel;
  final IconData? icon;

  const ModernConfirmDialog({
    super.key,
    required this.title,
    this.content,
    this.message,
    this.confirmLabel = 'Confirmar',
    this.cancelLabel = 'Cancelar',
    this.confirmVariant = ModernButtonVariant.danger,
    required this.onConfirm,
    this.onCancel,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.bgElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      actionsPadding: const EdgeInsets.all(16),
      title: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: confirmVariant == ModernButtonVariant.danger
                    ? AppTheme.danger.withValues(alpha: 0.15)
                    : AppTheme.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: confirmVariant == ModernButtonVariant.danger
                    ? AppTheme.danger
                    : AppTheme.accent,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppTheme.text,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: content ??
          (message != null
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    message!,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                )
              : null),
      actions: [
        ModernButton(
          label: cancelLabel,
          variant: ModernButtonVariant.ghost,
          compact: true,
          onPressed: () {
            Navigator.pop(context);
            onCancel?.call();
          },
        ),
        const SizedBox(width: 8),
        ModernButton(
          label: confirmLabel,
          variant: confirmVariant,
          compact: true,
          onPressed: () {
            Navigator.pop(context);
            onConfirm();
          },
        ),
      ],
    );
  }
}
