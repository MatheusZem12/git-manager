import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/modern_button.dart';
import '../widgets/modern_card.dart';

class MergeScreen extends StatefulWidget {
  final String path;
  final ApiService api;
  final List<String> branches;
  final String? currentBranch;
  final void Function(String) onLog;

  const MergeScreen({
    super.key,
    required this.path,
    required this.api,
    required this.branches,
    required this.currentBranch,
    required this.onLog,
  });

  @override
  State<MergeScreen> createState() => _MergeScreenState();
}

class _MergeScreenState extends State<MergeScreen> with AutomaticKeepAliveClientMixin {
  String? _sourceBranch;
  String? _targetBranch;
  bool _squash = false;
  bool _noFF = false;
  bool _loading = false;
  bool _loadingPreview = false;
  Map<String, dynamic>? _preview;
  Map<String, dynamic>? _mergeStatus;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _targetBranch = widget.currentBranch;
    _checkMergeStatus();
  }

  @override
  void didUpdateWidget(covariant MergeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentBranch != oldWidget.currentBranch) {
      setState(() => _targetBranch = widget.currentBranch);
    }
  }

  Future<void> _checkMergeStatus() async {
    try {
      final status = await widget.api.getMergeStatus(widget.path);
      if (mounted) {
        setState(() => _mergeStatus = status);
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> _loadPreview() async {
    if (_sourceBranch == null || _targetBranch == null) return;
    if (_sourceBranch == _targetBranch) {
      setState(() {
        _preview = {
          'canMerge': false,
          'message': 'Source e target não podem ser a mesma branch.',
        };
      });
      return;
    }
    setState(() => _loadingPreview = true);
    try {
      final preview = await widget.api.getMergePreview(widget.path, _sourceBranch!, _targetBranch!);
      if (mounted) {
        setState(() {
          _preview = preview;
          _loadingPreview = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _preview = {'canMerge': false, 'message': 'Erro: $e'};
          _loadingPreview = false;
        });
      }
    }
  }

  Future<void> _doMerge() async {
    if (_sourceBranch == null || _targetBranch == null) return;
    setState(() => _loading = true);
    try {
      final result = await widget.api.mergeBranch(
        widget.path,
        _sourceBranch!,
        _targetBranch!,
        squash: _squash,
        noFF: _noFF,
      );
      widget.onLog(result);
      await _checkMergeStatus();
      if (mounted) {
        setState(() {
          _loading = false;
          _preview = null;
        });
      }
    } catch (e) {
      widget.onLog('Erro no merge: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _abortMerge() async {
    setState(() => _loading = true);
    try {
      final result = await widget.api.abortMerge(widget.path);
      widget.onLog(result);
      await _checkMergeStatus();
      if (mounted) {
        setState(() {
          _loading = false;
          _preview = null;
        });
      }
    } catch (e) {
      widget.onLog('Erro ao abortar: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resolveMerge() async {
    setState(() => _loading = true);
    try {
      final result = await widget.api.resolveMerge(
        widget.path,
        'Merge branch \'$_sourceBranch\' into $_targetBranch',
      );
      widget.onLog(result);
      await _checkMergeStatus();
      if (mounted) {
        setState(() => _loading = false);
      }
    } catch (e) {
      widget.onLog('Erro ao resolver: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  List<String> get _localBranches {
    return widget.branches.where((b) => !b.contains('remotes/')).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isMerging = _mergeStatus?['merging'] == true;
    final conflicts = (_mergeStatus?['conflicts'] as List<dynamic>?)?.cast<String>() ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Merge in progress alert
            if (isMerging) ...[
              _buildConflictCard(conflicts),
              const SizedBox(height: 16),
            ],

            // Header
            ModernCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.call_merge, color: AppTheme.accent, size: 22),
                      const SizedBox(width: 10),
                      const Text(
                        'Merge / Pull Request',
                        style: TextStyle(
                          color: AppTheme.text,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Combine mudanças de uma branch em outra. Visualize o preview antes de executar.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Branch selectors
            ModernCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Selecionar branches',
                    style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 500;
                      return isNarrow
                          ? Column(
                              children: [
                                _buildBranchDropdown(
                                  label: 'Source (de)',
                                  value: _sourceBranch,
                                  onChanged: (v) {
                                    setState(() {
                                      _sourceBranch = v;
                                      _preview = null;
                                    });
                                    _loadPreview();
                                  },
                                ),
                                const SizedBox(height: 10),
                                _buildBranchDropdown(
                                  label: 'Target (para)',
                                  value: _targetBranch,
                                  onChanged: (v) {
                                    setState(() {
                                      _targetBranch = v;
                                      _preview = null;
                                    });
                                    _loadPreview();
                                  },
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(
                                  child: _buildBranchDropdown(
                                    label: 'Source (de)',
                                    value: _sourceBranch,
                                    onChanged: (v) {
                                      setState(() {
                                        _sourceBranch = v;
                                        _preview = null;
                                      });
                                      _loadPreview();
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Padding(
                                  padding: EdgeInsets.only(top: 20),
                                  child: Icon(Icons.arrow_forward, color: AppTheme.textMuted, size: 18),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildBranchDropdown(
                                    label: 'Target (para)',
                                    value: _targetBranch,
                                    onChanged: (v) {
                                      setState(() {
                                        _targetBranch = v;
                                        _preview = null;
                                      });
                                      _loadPreview();
                                    },
                                  ),
                                ),
                              ],
                            );
                    },
                  ),
                  const SizedBox(height: 14),
                  // Options
                  Row(
                    children: [
                      _buildOptionChip(
                        label: 'Squash',
                        tooltip: 'Compacta todos os commits em um só',
                        selected: _squash,
                        onTap: () => setState(() => _squash = !_squash),
                      ),
                      const SizedBox(width: 10),
                      _buildOptionChip(
                        label: 'No fast-forward',
                        tooltip: 'Sempre cria um commit de merge',
                        selected: _noFF,
                        onTap: () => setState(() => _noFF = !_noFF),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Preview
            if (_loadingPreview)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(color: AppTheme.accent),
                ),
              )
            else if (_preview != null)
              _buildPreviewCard(),

            const SizedBox(height: 16),

            // Actions
            if (_preview != null && (_preview!['canMerge'] == true || isMerging))
              Row(
                children: [
                  if (!isMerging) ...[
                    Expanded(
                      child: ModernButton(
                        icon: Icons.call_merge,
                        label: _squash ? 'Squash Merge' : 'Executar Merge',
                        variant: ModernButtonVariant.primary,
                        onPressed: _loading ? null : _doMerge,
                      ),
                    ),
                  ],
                  if (isMerging) ...[
                    if (conflicts.isEmpty) ...[
                      Expanded(
                        child: ModernButton(
                          icon: Icons.check_circle,
                          label: 'Finalizar Merge',
                          variant: ModernButtonVariant.success,
                          onPressed: _loading ? null : _resolveMerge,
                        ),
                      ),
                    ],
                    const SizedBox(width: 10),
                    Expanded(
                      child: ModernButton(
                        icon: Icons.cancel,
                        label: 'Abortar Merge',
                        variant: ModernButtonVariant.danger,
                        onPressed: _loading ? null : _abortMerge,
                      ),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildConflictCard(List<String> conflicts) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Merge em andamento — conflitos detectados',
                style: TextStyle(
                  color: AppTheme.danger,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Arquivos em conflito:',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 6),
          ...conflicts.map((f) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Icon(Icons.insert_drive_file_outlined, color: AppTheme.danger.withValues(alpha: 0.7), size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    f,
                    style: TextStyle(color: AppTheme.danger.withValues(alpha: 0.9), fontSize: 12),
                  ),
                ),
              ],
            ),
          )),
          const SizedBox(height: 10),
          const Text(
            'Resolva os conflitos manualmente, depois clique em "Finalizar Merge".\nOu cancele com "Abortar Merge".',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchDropdown({
    required String label,
    required String? value,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.bgElevated,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.borderStrong),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: value,
              dropdownColor: AppTheme.bgElevated,
              style: const TextStyle(color: AppTheme.text, fontSize: 13),
              icon: const Icon(Icons.arrow_drop_down, color: AppTheme.textMuted),
              hint: const Text('Selecione...', style: TextStyle(color: AppTheme.textMuted)),
              items: _localBranches.map((branch) {
                return DropdownMenuItem<String>(
                  value: branch,
                  child: Text(
                    branch,
                    style: TextStyle(
                      color: branch == widget.currentBranch ? AppTheme.accent : AppTheme.text,
                      fontWeight: branch == widget.currentBranch ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOptionChip({
    required String label,
    required String tooltip,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppTheme.accent.withValues(alpha: 0.15) : AppTheme.bgElevated,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? AppTheme.accent.withValues(alpha: 0.5) : AppTheme.borderStrong,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: Icon(
                  selected ? Icons.check_box : Icons.check_box_outline_blank,
                  color: selected ? AppTheme.accent : AppTheme.textMuted,
                  size: 16,
                  key: ValueKey<bool>(selected),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppTheme.accent : AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewCard() {
    final canMerge = _preview!['canMerge'] == true;
    final message = _preview!['message']?.toString() ?? '';
    final commits = (_preview!['commits'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final filesChanged = (_preview!['filesChanged'] as num?)?.toInt() ?? 0;
    final insertions = (_preview!['insertions'] as num?)?.toInt() ?? 0;
    final deletions = (_preview!['deletions'] as num?)?.toInt() ?? 0;

    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                canMerge ? Icons.visibility : Icons.block,
                color: canMerge ? AppTheme.success : AppTheme.danger,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                canMerge ? 'Preview do Merge' : 'Não é possível merge',
                style: TextStyle(
                  color: canMerge ? AppTheme.success : AppTheme.danger,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          if (canMerge) ...[
            const SizedBox(height: 14),
            // Stats
            Row(
              children: [
                _buildStatBadge('$filesChanged arquivos', AppTheme.info),
                const SizedBox(width: 8),
                _buildStatBadge('+$insertions', AppTheme.success),
                const SizedBox(width: 8),
                _buildStatBadge('-$deletions', AppTheme.danger),
                const SizedBox(width: 8),
                _buildStatBadge('${commits.length} commits', AppTheme.warning),
              ],
            ),
            if (commits.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Commits que serão incluídos:',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.bg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderStrong),
                ),
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: commits.length,
                  padding: const EdgeInsets.all(8),
                  itemBuilder: (context, i) {
                    final c = commits[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              c['id']?.toString() ?? '',
                              style: TextStyle(
                                color: AppTheme.accent,
                                fontSize: 10,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c['message']?.toString() ?? '',
                                  style: const TextStyle(color: AppTheme.text, fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${c['author']?.toString() ?? ''} • ${_formatDate(c['date']?.toString())}',
                                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildStatBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}
