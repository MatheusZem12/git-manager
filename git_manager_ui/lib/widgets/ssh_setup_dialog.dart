import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      setState(() => _message = result);
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

  Future<void> _copyViaBackend() async {
    try {
      final result = await widget.api.copySshKey();
      setState(() => _message = result);
    } catch (e) {
      setState(() => _message = 'Erro ao copiar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.bgElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Configuração SSH', style: TextStyle(color: AppTheme.text)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 400, maxWidth: 500),
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
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
                    const Text(
                      'Nenhuma chave SSH encontrada neste computador.',
                      style: TextStyle(color: AppTheme.warning),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _generateKey,
                      icon: const Icon(Icons.vpn_key),
                      label: const Text('Gerar nova chave SSH'),
                    ),
                  ] else ...[
                    const Text(
                      'Chave pública encontrada:',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0C0E12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.borderStrong),
                      ),
                      child: SelectableText(
                        _publicKey,
                        style: const TextStyle(
                          color: Color(0xFFC9D1D9),
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _copyKey,
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text('Copiar'),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: _generateKey,
                          child: const Text('Gerar nova', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '1. Copie a chave acima\n2. Acesse github.com/settings/keys\n3. Clique em "New SSH key" e cole',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                  ],
                  if (_message.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      _message,
                      style: TextStyle(
                        color: _message.contains('Erro') ? AppTheme.danger : AppTheme.success,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}
