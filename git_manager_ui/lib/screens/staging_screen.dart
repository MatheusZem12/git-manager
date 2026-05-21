import 'package:flutter/material.dart';
import '../models/git_file_change.dart';
import '../services/api_service.dart';
import '../theme.dart';

class StagingScreen extends StatefulWidget {
  final String path;
  final ApiService api;
  final Function(String)? onLog;

  const StagingScreen({
    super.key,
    required this.path,
    required this.api,
    this.onLog,
  });

  @override
  State<StagingScreen> createState() => _StagingScreenState();
}

class _StagingScreenState extends State<StagingScreen> {
  List<GitFileChange> _changes = [];
  List<GitFileChange> _filtered = [];
  GitFileChange? _selected;
  String _diffText = '';
  bool _loading = true;
  bool _diffLoading = false;
  final _filterCtrl = TextEditingController();
  final _commitMsgCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadChanges();
  }

  Future<void> _loadChanges() async {
    setState(() => _loading = true);
    try {
      final changes = await widget.api.getFileChanges(widget.path);
      setState(() {
        _changes = changes;
        _applyFilter();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    final q = _filterCtrl.text.toLowerCase();
    if (q.isEmpty) {
      _filtered = List.from(_changes);
    } else {
      _filtered = _changes.where((c) => c.path.toLowerCase().contains(q)).toList();
    }
  }

  Future<void> _showDiff(GitFileChange change) async {
    setState(() {
      _selected = change;
      _diffLoading = true;
    });
    try {
      final diff = await widget.api.getFileDiff(widget.path, change.path, staged: change.staged);
      setState(() {
        _diffText = diff;
        _diffLoading = false;
      });
    } catch (e) {
      setState(() {
        _diffText = 'Erro ao carregar diff: $e';
        _diffLoading = false;
      });
    }
  }

  Future<void> _doCommit() async {
    final msg = _commitMsgCtrl.text.trim();
    if (msg.isEmpty) {
      widget.onLog?.call('⚠ Mensagem do commit não pode ser vazia.');
      return;
    }
    final selected = _changes.where((c) => c.staged).map((c) => c.path).toList();
    if (selected.isEmpty) {
      widget.onLog?.call('⚠ Nenhum arquivo selecionado para commit.');
      return;
    }
    widget.onLog?.call('⏳ Fazendo commit...');
    try {
      final result = await widget.api.commit(widget.path, msg, selected);
      widget.onLog?.call(result);
      _commitMsgCtrl.clear();
      await _loadChanges();
    } catch (e) {
      widget.onLog?.call('❌ Erro: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.accent));
    }
    if (_changes.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.done_all, size: 48, color: AppTheme.textMuted),
            SizedBox(height: 12),
            Text('Nenhuma alteração pendente', style: TextStyle(color: AppTheme.textMuted)),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        return Column(
          children: [
            // Filter bar
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _filterCtrl,
                    style: const TextStyle(color: AppTheme.text, fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'Filtrar por nome...',
                      prefixIcon: Icon(Icons.search, size: 18),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: (_) => setState(() => _applyFilter()),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    setState(() {
                      for (final c in _changes) {
                        c.staged = true;
                      }
                    });
                  },
                  child: const Text('Todos'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      for (final c in _changes) {
                        c.staged = false;
                      }
                    });
                  },
                  child: const Text('Nenhum'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Content area
            Expanded(
              child: isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 1, child: _buildFileList()),
                        const VerticalDivider(width: 1),
                        Expanded(flex: 1, child: _buildDiffPreview()),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 1, child: _buildFileList()),
                        const Divider(height: 1),
                        Expanded(flex: 1, child: _buildDiffPreview()),
                      ],
                    ),
            ),
            const SizedBox(height: 12),
            // Commit bar
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commitMsgCtrl,
                    style: const TextStyle(color: AppTheme.text),
                    decoration: const InputDecoration(
                      hintText: 'Mensagem do commit...',
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (_) => _doCommit(),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _doCommit,
                  icon: const Icon(Icons.check),
                  label: const Text('Commit'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warning),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildFileList() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgElevated.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Scrollbar(
        child: ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: _filtered.length,
          itemBuilder: (_, i) {
            final change = _filtered[i];
            final isSel = _selected?.path == change.path;
            return Material(
              color: isSel ? AppTheme.accent.withValues(alpha: 0.08) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: () => _showDiff(change),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    children: [
                      Checkbox(
                        value: change.staged,
                        onChanged: (v) {
                          setState(() => change.staged = v ?? false);
                        },
                        activeColor: AppTheme.accent,
                        side: const BorderSide(color: AppTheme.textMuted),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              change.path,
                              style: TextStyle(
                                color: change.type == 'DELETED' || change.type == 'CONFLICTING'
                                    ? Color(change.colorValue)
                                    : AppTheme.text,
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Color(change.colorValue).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          change.label,
                          style: TextStyle(
                            color: Color(change.colorValue),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDiffPreview() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0E12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderStrong.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selected != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_selected!.path} — ${_selected!.label}',
                    style: TextStyle(
                      color: Color(_selected!.colorValue),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_diffLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
                  ),
              ],
            ),
          if (_selected == null)
            const Text(
              'Selecione um arquivo para visualizar o diff',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: _diffLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
                : Scrollbar(
                    child: SingleChildScrollView(
                      child: SelectableText(
                        _diffText,
                        style: const TextStyle(
                          color: Color(0xFFC9D1D9),
                          fontFamily: 'monospace',
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
