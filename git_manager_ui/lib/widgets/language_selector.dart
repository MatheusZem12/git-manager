import 'package:flutter/material.dart';
import '../theme.dart';

class LanguageSelector extends StatelessWidget {
  final Locale currentLocale;
  final ValueChanged<Locale> onChanged;

  const LanguageSelector({
    super.key,
    required this.currentLocale,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final locales = [
      const Locale('pt', 'BR'),
      const Locale('en', 'US'),
      const Locale('es', 'ES'),
    ];

    final labels = {
      'pt': 'PT',
      'en': 'EN',
      'es': 'ES',
    };

    final flags = {
      'pt': '🇧🇷',
      'en': '🇺🇸',
      'es': '🇪🇸',
    };

    return PopupMenuButton<Locale>(
      tooltip: 'Idioma / Language',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.borderStrong.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              flags[currentLocale.languageCode] ?? '🌐',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(width: 6),
            Text(
              labels[currentLocale.languageCode] ?? currentLocale.languageCode.toUpperCase(),
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down, color: AppTheme.textMuted, size: 16),
          ],
        ),
      ),
      color: AppTheme.bgElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) => locales.map((l) {
        final isSelected = l.languageCode == currentLocale.languageCode;
        return PopupMenuItem(
          value: l,
          child: Row(
            children: [
              Text(flags[l.languageCode] ?? '🌐', style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 10),
              Text(
                labels[l.languageCode] ?? l.languageCode.toUpperCase(),
                style: TextStyle(
                  color: AppTheme.text,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 8),
                const Icon(Icons.check, color: AppTheme.accent, size: 16),
              ],
            ],
          ),
        );
      }).toList(),
      onSelected: onChanged,
    );
  }
}
