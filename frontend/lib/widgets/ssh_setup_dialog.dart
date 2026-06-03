import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../theme.dart';

class SshSetupDialog extends StatefulWidget {
  final ApiService api;

  const SshSetupDialog({super.key, required this.api});

  @override
  State<SshSetupDialog> createState() => _SshSetupDialogState();

  static Future<void> show(BuildContext context, ApiService api) {
    return showDialog(
      context: context,
      builder: (_) => SshSetupDialog(api: api),
    );
  }
}

class _SshSetupDialogState extends State<SshSetupDialog> {
  bool _loading = true;
  bool _hasKey = false;
  String _publicKey = '';
  String _message = '';
  bool _justGenerated = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final data = await widget.api.getSshStatus();
      setState(() {
        _hasKey = data['hasKey'] ?? false;
        _publicKey = data['publicKey'] ?? '';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _message = 'Erro ao carregar status SSH: $e';
        _loading = false;
      });
    }
  }

  Future<void> _generateKey() async {
    setState(() => _loading = true);
    try {
      final result = await widget.api.generateSshKey();
      setState(() {
        _message = result;
        _justGenerated = true;
      });
      await _loadStatus();
    } catch (e) {
      setState(() {
        _message = 'Erro: $e';
        _loading = false;
      });
    }
  }

  Future<void> _copyKey() async {
    if (_publicKey.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _publicKey));
    setState(() => _message = 'Chave pública copiada!');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.bgElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.key, color: AppTheme.accent, size: 22),
          const SizedBox(width: 10),
          const Text('Configuração SSH', style: TextStyle(color: AppTheme.text)),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 420, maxWidth: 520),
        child: _loading
            ? const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Para usar push/pull com repositórios SSH, você precisa de uma chave SSH configurada no GitHub.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  if (!_hasKey) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Nenhuma chave SSH encontrada neste computador.',
                              style: TextStyle(color: AppTheme.warning, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _generateKey,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.vpn_key, size: 18),
                        label: const Text('Gerar nova chave SSH', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: AppTheme.success, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          _justGenerated ? 'Chave SSH gerada!' : 'Chave pública encontrada:',
                          style: TextStyle(
                            color: _justGenerated ? AppTheme.success : AppTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: _justGenerated ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0C0E12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _justGenerated ? AppTheme.success.withValues(alpha: 0.4) : AppTheme.borderStrong,
                        ),
                      ),
                      child: SelectableText(
                        _publicKey,
                        style: const TextStyle(
                          color: Color(0xFFC9D1D9),
                          fontFamily: 'monospace',
                          fontSize: 11,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _CopyButton(
                            onPressed: _copyKey,
                            label: 'Copiar chave',
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: _generateKey,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.textSecondary,
                            side: BorderSide(color: AppTheme.borderStrong),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Gerar nova', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.15)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Como adicionar ao GitHub:',
                            style: TextStyle(
                              color: AppTheme.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _buildStep('1', 'Clique em "Copiar chave" acima'),
                          _buildStepLink(
                            '2',
                            'Acesse ',
                            'github.com/settings/keys',
                            'https://github.com/settings/keys',
                          ),
                          _buildStep('3', 'Clique em "New SSH key", cole e salve'),
                        ],
                      ),
                    ),
                  ],
                  if (_message.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _message.contains('Erro') || _message.contains('existe')
                            ? AppTheme.danger.withValues(alpha: 0.08)
                            : AppTheme.success.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _message.contains('Erro') || _message.contains('existe')
                              ? AppTheme.danger.withValues(alpha: 0.25)
                              : AppTheme.success.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Text(
                        _message,
                        style: TextStyle(
                          color: _message.contains('Erro') || _message.contains('existe')
                              ? AppTheme.danger
                              : AppTheme.success,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: AppTheme.textSecondary),
          child: const Text('Fechar'),
        ),
      ],
    );
  }

  Widget _buildStepLink(String number, String prefix, String linkText, String url) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: AppTheme.accent,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              children: [
                Text(
                  prefix,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                GestureDetector(
                  onTap: () async {
                    final uri = Uri.parse(url);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  child: Text(
                    linkText,
                    style: const TextStyle(
                      color: AppTheme.accent,
                      fontSize: 12,
                      decoration: TextDecoration.underline,
                      decorationColor: AppTheme.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: AppTheme.accent,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _CopyButton extends StatefulWidget {
  final VoidCallback onPressed;
  final String label;

  const _CopyButton({required this.onPressed, required this.label});

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  void _handlePress() {
    widget.onPressed();
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: _handlePress,
      style: ElevatedButton.styleFrom(
        backgroundColor: _copied ? AppTheme.success : AppTheme.accent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Icon(
          _copied ? Icons.check : Icons.copy,
          size: 16,
          key: ValueKey<bool>(_copied),
        ),
      ),
      label: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Text(
          _copied ? 'Copiado!' : widget.label,
          key: ValueKey<bool>(_copied),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
