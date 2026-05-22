import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
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
  String _oldContent = '';
  String _newContent = '';
  bool _loading = true;
  bool _diffLoading = false;
  int _previewTab = 0; // 0 = Diff, 1 = Arquivo
  final _filterCtrl = TextEditingController();
  final _commitMsgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

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
      _previewTab = 0;
    });
    try {
      final oldText = await widget.api.getFileContentHead(widget.path, change.path);
      final newText = await widget.api.getFileContent(widget.path, change.path);
      setState(() {
        _oldContent = oldText;
        _newContent = newText;
        _diffLoading = false;
      });
    } catch (e) {
      setState(() {
        _oldContent = '';
        _newContent = '';
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
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.done_all, size: 48, color: AppTheme.textMuted),
            const SizedBox(height: 12),
            Text(AppLocalizations.of(context)!.noChanges, style: const TextStyle(color: AppTheme.textMuted)),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _filterCtrl,
                    style: const TextStyle(color: AppTheme.text, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)!.filterFiles,
                      prefixIcon: Icon(Icons.search, size: 18),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: (_) => setState(() => _applyFilter()),
                  ),
                ),
                const SizedBox(width: 8),
                _ChipButton(label: AppLocalizations.of(context)!.all, onTap: () {
                  setState(() { for (final c in _changes) { c.staged = true; } });
                }),
                const SizedBox(width: 6),
                _ChipButton(label: AppLocalizations.of(context)!.none, onTap: () {
                  setState(() { for (final c in _changes) { c.staged = false; } });
                }),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 1, child: _buildFileList()),
                        const VerticalDivider(width: 1),
                        Expanded(flex: 2, child: _buildDiffPreview()),
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
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.bgElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderStrong.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commitMsgCtrl,
                      style: const TextStyle(color: AppTheme.text),
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context)!.commitMessage,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        filled: true,
                        fillColor: AppTheme.surface,
                      ),
                      onSubmitted: (_) => _doCommit(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _CommitButton(onPressed: _doCommit),
                ],
              ),
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
                        onChanged: (v) => setState(() => change.staged = v ?? false),
                        activeColor: AppTheme.accent,
                        side: const BorderSide(color: AppTheme.textMuted),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          change.path,
                          style: TextStyle(
                            color: change.type == 'DELETED' || change.type == 'CONFLICTING'
                                ? Color(change.colorValue) : AppTheme.text,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
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
                    _selected!.path,
                    style: TextStyle(
                      color: Color(_selected!.colorValue),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Color(_selected!.colorValue).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _selected!.label,
                    style: TextStyle(
                      color: Color(_selected!.colorValue),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_diffLoading)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
                    ),
                  ),
              ],
            ),
          if (_selected == null)
            Text(
              AppLocalizations.of(context)!.selectFile,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
          const SizedBox(height: 8),
          if (_selected != null && !_diffLoading) ...[
            // Tabs
            Row(
              children: [
                _DiffTab(label: AppLocalizations.of(context)!.diff, active: _previewTab == 0, onTap: () => setState(() => _previewTab = 0)),
                const SizedBox(width: 8),
                _DiffTab(label: AppLocalizations.of(context)!.file, active: _previewTab == 1, onTap: () => setState(() => _previewTab = 1)),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 600;
                  return _previewTab == 0
                      ? isNarrow
                          ? _UnifiedDiff(oldContent: _oldContent, newContent: _newContent)
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 6),
                                        decoration: BoxDecoration(
                                          color: AppTheme.bgElevated.withValues(alpha: 0.5),
                                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                                        ),
                                        child: Center(
                                          child: Text(
                                            AppLocalizations.of(context)!.before,
                                            style: TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Container(width: 1, color: AppTheme.borderStrong),
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 6),
                                        decoration: BoxDecoration(
                                          color: AppTheme.bgElevated.withValues(alpha: 0.5),
                                          borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                                        ),
                                        child: Center(
                                          child: Text(
                                            AppLocalizations.of(context)!.after,
                                            style: TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Expanded(
                                  child: _SideBySideDiff(
                                    oldContent: _oldContent,
                                    newContent: _newContent,
                                    scrollController: _scrollCtrl,
                                  ),
                                ),
                              ],
                            )
                      : _FileViewer(content: _newContent);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------
// Botão de commit elegante
// ------------------------------------------------------------------
class _CommitButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _CommitButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context)!.commit,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------
// Tab do diff viewer
// ------------------------------------------------------------------
class _DiffTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _DiffTab({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: active ? AppTheme.accent.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active ? AppTheme.accent.withValues(alpha: 0.4) : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? AppTheme.accentHover : AppTheme.textMuted,
              fontSize: 12,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------
// Chip de ação
// ------------------------------------------------------------------
class _ChipButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ChipButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.borderStrong.withValues(alpha: 0.4)),
          ),
          child: Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------
// File Viewer (arquivo atual sem cores)
// ------------------------------------------------------------------
class _FileViewer extends StatelessWidget {
  final String content;

  const _FileViewer({required this.content});

  @override
  Widget build(BuildContext context) {
    final lines = content.split('\n');
    return Scrollbar(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int i = 0; i < lines.length; i++)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1.5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 36,
                      child: Text(
                        '${i + 1}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontFamily: 'monospace',
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SelectableText(
                        lines[i],
                        style: const TextStyle(
                          color: Color(0xFFC9D1D9),
                          fontFamily: 'monospace',
                          fontSize: 11.5,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------
// Side-by-side Diff Viewer (estilo VS Code)
// ------------------------------------------------------------------
class _SideBySideDiff extends StatefulWidget {
  final String oldContent;
  final String newContent;
  final ScrollController scrollController;

  const _SideBySideDiff({
    required this.oldContent,
    required this.newContent,
    required this.scrollController,
  });

  @override
  State<_SideBySideDiff> createState() => _SideBySideDiffState();
}

class _SideBySideDiffState extends State<_SideBySideDiff> {
  late final List<_DiffRow> _rows;

  @override
  void initState() {
    super.initState();
    _rows = _computeDiff(widget.oldContent, widget.newContent);
  }

  @override
  void didUpdateWidget(covariant _SideBySideDiff oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.oldContent != widget.oldContent || oldWidget.newContent != widget.newContent) {
      _rows = _computeDiff(widget.oldContent, widget.newContent);
    }
  }

  List<_DiffRow> _computeDiff(String oldText, String newText) {
    final oldLines = oldText.split('\n');
    final newLines = newText.split('\n');
    final rows = <_DiffRow>[];

    int o = 0;
    int n = 0;

    while (o < oldLines.length || n < newLines.length) {
      if (o < oldLines.length && n < newLines.length && oldLines[o] == newLines[n]) {
        // Linha igual
        rows.add(_DiffRow(
          leftLine: oldLines[o],
          rightLine: newLines[n],
          leftType: _LineType.normal,
          rightType: _LineType.normal,
          leftNum: o + 1,
          rightNum: n + 1,
        ));
        o++;
        n++;
      } else {
        // Encontrar o próximo ponto de sincronização
        int matchOld = -1;
        int matchNew = -1;
        int maxLookAhead = 8;

        for (int i = 0; i < maxLookAhead && o + i < oldLines.length; i++) {
          for (int j = 0; j < maxLookAhead && n + j < newLines.length; j++) {
            if (oldLines[o + i] == newLines[n + j]) {
              matchOld = i;
              matchNew = j;
              break;
            }
          }
          if (matchOld >= 0) break;
        }

        if (matchOld < 0) {
          // Sem ponto de sincronização próximo, tratar o resto como mudança
          while (o < oldLines.length || n < newLines.length) {
            if (o < oldLines.length && n < newLines.length) {
              rows.add(_DiffRow(
                leftLine: oldLines[o],
                rightLine: newLines[n],
                leftType: _LineType.removed,
                rightType: _LineType.added,
                leftNum: o + 1,
                rightNum: n + 1,
              ));
              o++;
              n++;
            } else if (o < oldLines.length) {
              rows.add(_DiffRow(
                leftLine: oldLines[o],
                rightLine: null,
                leftType: _LineType.removed,
                rightType: _LineType.empty,
                leftNum: o + 1,
                rightNum: null,
              ));
              o++;
            } else {
              rows.add(_DiffRow(
                leftLine: null,
                rightLine: newLines[n],
                leftType: _LineType.empty,
                rightType: _LineType.added,
                leftNum: null,
                rightNum: n + 1,
              ));
              n++;
            }
          }
        } else {
          // Emitir as linhas diferentes como removidas/adicionadas
          for (int i = 0; i < matchOld || i < matchNew; i++) {
            final oldLine = i < matchOld ? oldLines[o + i] : null;
            final newLine = i < matchNew ? newLines[n + i] : null;
            rows.add(_DiffRow(
              leftLine: oldLine,
              rightLine: newLine,
              leftType: oldLine != null ? _LineType.removed : _LineType.empty,
              rightType: newLine != null ? _LineType.added : _LineType.empty,
              leftNum: oldLine != null ? o + i + 1 : null,
              rightNum: newLine != null ? n + i + 1 : null,
            ));
          }
          o += matchOld;
          n += matchNew;
        }
      }
    }

    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: widget.scrollController,
      child: SingleChildScrollView(
        controller: widget.scrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _rows.map((row) => _DiffRowWidget(row: row)).toList(),
        ),
      ),
    );
  }
}

class _UnifiedDiff extends StatelessWidget {
  final String oldContent;
  final String newContent;

  const _UnifiedDiff({required this.oldContent, required this.newContent});

  @override
  Widget build(BuildContext context) {
    final oldLines = oldContent.split('\n');
    final newLines = newContent.split('\n');
    final rows = <Widget>[];

    int o = 0, n = 0;
    while (o < oldLines.length || n < newLines.length) {
      if (o < oldLines.length && n < newLines.length && oldLines[o] == newLines[n]) {
        rows.add(_UnifiedLine(line: oldLines[o], type: _LineType.normal, oldNum: o + 1, newNum: n + 1));
        o++; n++;
      } else {
        int matchOld = -1, matchNew = -1;
        const maxLookAhead = 8;
        for (int i = 0; i < maxLookAhead && o + i < oldLines.length; i++) {
          for (int j = 0; j < maxLookAhead && n + j < newLines.length; j++) {
            if (oldLines[o + i] == newLines[n + j]) { matchOld = i; matchNew = j; break; }
          }
          if (matchOld >= 0) break;
        }
        if (matchOld < 0) {
          while (o < oldLines.length || n < newLines.length) {
            if (o < oldLines.length && n < newLines.length) {
              rows.add(_UnifiedLine(line: '- ${oldLines[o]}', type: _LineType.removed, oldNum: o + 1));
              rows.add(_UnifiedLine(line: '+ ${newLines[n]}', type: _LineType.added, newNum: n + 1));
              o++; n++;
            } else if (o < oldLines.length) {
              rows.add(_UnifiedLine(line: '- ${oldLines[o]}', type: _LineType.removed, oldNum: o + 1));
              o++;
            } else {
              rows.add(_UnifiedLine(line: '+ ${newLines[n]}', type: _LineType.added, newNum: n + 1));
              n++;
            }
          }
        } else {
          for (int i = 0; i < matchOld; i++) {
            rows.add(_UnifiedLine(line: '- ${oldLines[o + i]}', type: _LineType.removed, oldNum: o + i + 1));
          }
          for (int j = 0; j < matchNew; j++) {
            rows.add(_UnifiedLine(line: '+ ${newLines[n + j]}', type: _LineType.added, newNum: n + j + 1));
          }
          o += matchOld; n += matchNew;
        }
      }
    }

    return Container(
      decoration: BoxDecoration(color: AppTheme.bgElevated, borderRadius: BorderRadius.circular(8)),
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: rows.length,
        itemBuilder: (_, i) => rows[i],
      ),
    );
  }
}

class _UnifiedLine extends StatelessWidget {
  final String line;
  final _LineType type;
  final int? oldNum;
  final int? newNum;

  const _UnifiedLine({required this.line, required this.type, this.oldNum, this.newNum});

  @override
  Widget build(BuildContext context) {
    final bg = switch (type) {
      _LineType.added => const Color(0xFF0F2D1F),
      _LineType.removed => const Color(0xFF3D1515),
      _ => Colors.transparent,
    };
    final fg = switch (type) {
      _LineType.added => const Color(0xFF7EE787),
      _LineType.removed => const Color(0xFFFF7B72),
      _ => const Color(0xFFC9D1D9),
    };
    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 30, child: Text(oldNum?.toString() ?? '', textAlign: TextAlign.right, style: const TextStyle(color: Color(0xFF5E6A7A), fontFamily: 'monospace', fontSize: 10))),
          const SizedBox(width: 4),
          SizedBox(width: 30, child: Text(newNum?.toString() ?? '', textAlign: TextAlign.right, style: const TextStyle(color: Color(0xFF5E6A7A), fontFamily: 'monospace', fontSize: 10))),
          const SizedBox(width: 8),
          Expanded(child: SelectableText(line, style: TextStyle(color: fg, fontFamily: 'monospace', fontSize: 11.5, height: 1.35))),
        ],
      ),
    );
  }
}

class _DiffRow {
  final String? leftLine;
  final String? rightLine;
  final _LineType leftType;
  final _LineType rightType;
  final int? leftNum;
  final int? rightNum;

  _DiffRow({
    required this.leftLine,
    required this.rightLine,
    required this.leftType,
    required this.rightType,
    required this.leftNum,
    required this.rightNum,
  });
}

enum _LineType { normal, added, removed, empty }

class _DiffRowWidget extends StatelessWidget {
  final _DiffRow row;

  const _DiffRowWidget({required this.row});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _LineCell(
            line: row.leftLine,
            lineNum: row.leftNum,
            type: row.leftType,
          )),
          Container(width: 1, color: AppTheme.borderStrong.withValues(alpha: 0.3)),
          Expanded(child: _LineCell(
            line: row.rightLine,
            lineNum: row.rightNum,
            type: row.rightType,
          )),
        ],
      ),
    );
  }
}

class _LineCell extends StatelessWidget {
  final String? line;
  final int? lineNum;
  final _LineType type;

  const _LineCell({required this.line, required this.lineNum, required this.type});

  @override
  Widget build(BuildContext context) {
    final bg = switch (type) {
      _LineType.added => const Color(0xFF0D2818),
      _LineType.removed => const Color(0xFF3A0D0D),
      _LineType.empty => const Color(0xFF0C0E12),
      _LineType.normal => Colors.transparent,
    };

    final fg = switch (type) {
      _LineType.added => const Color(0xFF7EE787),
      _LineType.removed => const Color(0xFFFF7B72),
      _LineType.empty => const Color(0xFF5E6A7A),
      _LineType.normal => const Color(0xFFC9D1D9),
    };

    final numColor = switch (type) {
      _LineType.added => const Color(0xFF3FB950),
      _LineType.removed => const Color(0xFFF85149),
      _LineType.empty => const Color(0xFF5E6A7A),
      _LineType.normal => const Color(0xFF5E6A7A),
    };

    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 36,
            child: Text(
              lineNum?.toString() ?? '',
              textAlign: TextAlign.right,
              style: TextStyle(color: numColor, fontFamily: 'monospace', fontSize: 10),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              line ?? '',
              style: TextStyle(color: fg, fontFamily: 'monospace', fontSize: 11.5, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
