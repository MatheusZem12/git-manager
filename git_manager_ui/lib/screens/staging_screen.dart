import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../models/git_file_change.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../utils/responsive.dart';
import '../widgets/modern_button.dart';
import '../widgets/modern_dialog.dart';

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
  int _previewTab = 0;
  final _filterCtrl = TextEditingController();
  final _commitMsgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _unstagedScrollCtrl = ScrollController();
  final _stagedScrollCtrl = ScrollController();
  final Set<String> _selUnstaged = <String>{};
  final Set<String> _selStaged = <String>{};

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
        _selUnstaged
            .removeWhere((p) => !changes.any((c) => c.path == p && !c.staged));
        _selStaged
            .removeWhere((p) => !changes.any((c) => c.path == p && c.staged));
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    final q = _filterCtrl.text.toLowerCase();
    _filtered = q.isEmpty
        ? List.from(_changes)
        : _changes.where((c) => c.path.toLowerCase().contains(q)).toList();
  }

  Future<void> _showDiff(GitFileChange change) async {
    setState(() {
      _selected = change;
      _diffLoading = true;
      _previewTab = 0;
    });
    try {
      final oldText =
          await widget.api.getFileContentHead(widget.path, change.path);
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
    final l10n = AppLocalizations.of(context)!;
    final msg = _commitMsgCtrl.text.trim();
    if (msg.isEmpty) {
      widget.onLog?.call(l10n.commitMessageEmpty);
      return;
    }
    if (_changes.where((c) => c.staged).isEmpty) {
      widget.onLog?.call(l10n.noFilesSelected);
      return;
    }
    widget.onLog?.call(l10n.creatingCommit);
    try {
      final result = await widget.api.commitStaged(widget.path, msg);
      widget.onLog?.call(result);
      _commitMsgCtrl.clear();
      await _loadChanges();
    } catch (e) {
      widget.onLog?.call('${l10n.error}: $e');
    }
  }

  Future<void> _doStage() async {
    final l10n = AppLocalizations.of(context)!;
    final files = _selUnstaged.toList();
    if (files.isEmpty) {
      widget.onLog?.call(l10n.nothingToStage);
      return;
    }
    widget.onLog?.call('${l10n.stageSelected} (${files.length})');
    try {
      final result = await widget.api.stageFiles(widget.path, files);
      widget.onLog?.call(result);
      setState(() => _selUnstaged.clear());
      await _loadChanges();
    } catch (e) {
      widget.onLog?.call('${l10n.error}: $e');
    }
  }

  Future<void> _doUnstage() async {
    final l10n = AppLocalizations.of(context)!;
    final files = _selStaged.toList();
    if (files.isEmpty) {
      widget.onLog?.call(l10n.nothingToUnstage);
      return;
    }
    widget.onLog?.call('${l10n.unstageSelected} (${files.length})');
    try {
      final result = await widget.api.unstageFiles(widget.path, files);
      widget.onLog?.call(result);
      setState(() => _selStaged.clear());
      await _loadChanges();
    } catch (e) {
      widget.onLog?.call('${l10n.error}: $e');
    }
  }

  Future<void> _openFile() async {
    final l10n = AppLocalizations.of(context)!;
    final file = _selected;
    if (file == null) return;
    final filePath = '${widget.path}/${file.path}';
    try {
      if (Platform.isLinux) {
        await Process.run('xdg-open', [filePath]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [filePath]);
      } else if (Platform.isWindows) {
        await Process.run('start', ['""', filePath], runInShell: true);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(l10n.comingSoon),
                duration: const Duration(seconds: 2)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('${l10n.error}: $e'),
              duration: const Duration(seconds: 2)),
        );
      }
    }
  }

  void _discardChanges() {
    final l10n = AppLocalizations.of(context)!;
    final file = _selected;
    if (file == null) return;
    showDialog(
      context: context,
      builder: (_) => ModernConfirmDialog(
        title: l10n.discardChanges,
        message: l10n.discardChangesConfirm(file.path),
        confirmLabel: l10n.discardChanges,
        cancelLabel: l10n.cancel,
        confirmVariant: ModernButtonVariant.danger,
        icon: Icons.restore_from_trash,
        onConfirm: () async {
          widget.onLog?.call('${l10n.discardChanges} — ${file.path}');
          try {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(l10n.comingSoon),
                    duration: const Duration(seconds: 2)),
              );
            }
          } catch (e) {
            widget.onLog?.call('${l10n.error}: $e');
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.accent));
    }
    if (_changes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.done_all, size: 32, color: AppTheme.textMuted),
            const SizedBox(height: 6),
            Text(l10n.noChanges,
                style:
                    const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final s = Responsive.scale(constraints.maxWidth, base: 900);
        final isWide = constraints.maxWidth > 700;
        final unstaged = _filtered.where((c) => !c.staged).toList();
        final staged = _filtered.where((c) => c.staged).toList();

        final filePanel = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: staged.isEmpty ? 1 : 2,
              child: _FileSection(
                title: l10n.unstagedFiles,
                count: unstaged.length,
                color: AppTheme.warning,
                files: unstaged,
                selected: _selected,
                selection: _selUnstaged,
                onToggle: (p) => setState(() => _selUnstaged.contains(p)
                    ? _selUnstaged.remove(p)
                    : _selUnstaged.add(p)),
                onSelect: _showDiff,
                onSelectAll: () => setState(
                    () => _selUnstaged.addAll(unstaged.map((c) => c.path))),
                onDeselectAll: () => setState(
                    () => _selUnstaged.removeAll(unstaged.map((c) => c.path))),
                actionLabel: l10n.stage,
                actionIcon: Icons.arrow_upward,
                actionVariant: ModernButtonVariant.success,
                onAction: _doStage,
                scale: s,
                scrollController: _unstagedScrollCtrl,
              ),
            ),
            if (staged.isNotEmpty) ...[
              SizedBox(height: Responsive.pad(6, s)),
              Expanded(
                child: _FileSection(
                  title: l10n.stagedFiles,
                  count: staged.length,
                  color: AppTheme.success,
                  files: staged,
                  selected: _selected,
                  selection: _selStaged,
                  onToggle: (p) => setState(() => _selStaged.contains(p)
                      ? _selStaged.remove(p)
                      : _selStaged.add(p)),
                  onSelect: _showDiff,
                  onSelectAll: () => setState(
                      () => _selStaged.addAll(staged.map((c) => c.path))),
                  onDeselectAll: () => setState(
                      () => _selStaged.removeAll(staged.map((c) => c.path))),
                  actionLabel: l10n.unstage,
                  actionIcon: Icons.arrow_downward,
                  actionVariant: ModernButtonVariant.warning,
                  onAction: _doUnstage,
                  scale: s,
                  scrollController: _stagedScrollCtrl,
                ),
              ),
            ],
          ],
        );

        final diffPanel = _buildDiffPreview(s);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Filter bar
            TextField(
              controller: _filterCtrl,
              style: TextStyle(
                  color: AppTheme.text, fontSize: Responsive.font(12, s)),
              decoration: InputDecoration(
                hintText: l10n.filterFiles,
                prefixIcon: Icon(Icons.search, size: Responsive.icon(14, s)),
                contentPadding: EdgeInsets.symmetric(
                    horizontal: Responsive.pad(8, s),
                    vertical: Responsive.pad(4, s)),
                isDense: true,
              ),
              onChanged: (_) => setState(() => _applyFilter()),
            ),
            SizedBox(height: Responsive.pad(6, s)),
            // Main area
            Expanded(
              child: isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 1, child: filePanel),
                        const VerticalDivider(width: 1),
                        Expanded(flex: 2, child: diffPanel),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 2, child: filePanel),
                        const Divider(height: 1),
                        Expanded(flex: 2, child: diffPanel),
                      ],
                    ),
            ),
            SizedBox(height: Responsive.pad(6, s)),
            // Commit bar
            Container(
              padding: EdgeInsets.symmetric(
                  horizontal: Responsive.pad(8, s),
                  vertical: Responsive.pad(5, s)),
              decoration: BoxDecoration(
                color: AppTheme.bgElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppTheme.borderStrong.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commitMsgCtrl,
                      style: TextStyle(
                          color: AppTheme.text,
                          fontSize: Responsive.font(12, s)),
                      decoration: InputDecoration(
                        hintText: l10n.commitMessage,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: Responsive.pad(8, s),
                            vertical: Responsive.pad(5, s)),
                        filled: true,
                        fillColor: AppTheme.surface,
                        isDense: true,
                      ),
                      onSubmitted: (_) => _doCommit(),
                    ),
                  ),
                  SizedBox(width: Responsive.pad(6, s)),
                  _CommitButton(
                      scale: s,
                      stagedCount: staged.length,
                      onPressed: _doCommit),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDiffPreview(double scale) {
    final l10n = AppLocalizations.of(context)!;
    if (_selected == null) {
      return Container(
        color: const Color(0xFF0C0E12),
        child: Center(
          child: Text(l10n.selectFile,
              style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: Responsive.font(11, scale))),
        ),
      );
    }
    return Container(
      color: const Color(0xFF0C0E12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // File header
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: Responsive.pad(8, scale),
                vertical: Responsive.pad(4, scale)),
            decoration: BoxDecoration(
                color: AppTheme.bgElevated.withValues(alpha: 0.5)),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _selected!.path,
                    style: TextStyle(
                        color: Color(_selected!.colorValue),
                        fontSize: Responsive.font(10, scale),
                        fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: Responsive.pad(4, scale)),
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: Responsive.pad(4, scale),
                      vertical: Responsive.pad(1, scale)),
                  decoration: BoxDecoration(
                    color: Color(_selected!.colorValue).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _selected!.labelText(l10n),
                    style: TextStyle(
                        color: Color(_selected!.colorValue),
                        fontSize: Responsive.font(8, scale),
                        fontWeight: FontWeight.bold),
                  ),
                ),
                if (_diffLoading)
                  Padding(
                    padding: EdgeInsets.only(left: Responsive.pad(4, scale)),
                    child: SizedBox(
                        width: Responsive.icon(10, scale),
                        height: Responsive.icon(10, scale),
                        child: const CircularProgressIndicator(
                            strokeWidth: 2, color: AppTheme.accent)),
                  ),
                SizedBox(width: Responsive.pad(4, scale)),
                ModernButton(
                    icon: Icons.open_in_new,
                    variant: ModernButtonVariant.ghost,
                    tiny: true,
                    scale: scale,
                    onPressed: _openFile),
                SizedBox(width: Responsive.pad(3, scale)),
                ModernButton(
                    icon: Icons.restore_from_trash,
                    variant: ModernButtonVariant.danger,
                    tiny: true,
                    scale: scale,
                    onPressed: _discardChanges),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.borderStrong),
          // Tabs
          if (!_diffLoading)
            Container(
              padding: EdgeInsets.symmetric(
                  horizontal: Responsive.pad(6, scale),
                  vertical: Responsive.pad(3, scale)),
              child: Row(
                children: [
                  _DiffTab(
                      label: l10n.diff,
                      active: _previewTab == 0,
                      scale: scale,
                      onTap: () => setState(() => _previewTab = 0)),
                  SizedBox(width: Responsive.pad(4, scale)),
                  _DiffTab(
                      label: l10n.file,
                      active: _previewTab == 1,
                      scale: scale,
                      onTap: () => setState(() => _previewTab = 1)),
                ],
              ),
            ),
          // Content
          if (!_diffLoading)
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 600;
                  return _previewTab == 0
                      ? isNarrow
                          ? _UnifiedDiff(
                              oldContent: _oldContent,
                              newContent: _newContent,
                              scale: scale)
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                            vertical: Responsive.pad(2, scale)),
                                        decoration: BoxDecoration(
                                            color: AppTheme.bgElevated
                                                .withValues(alpha: 0.5)),
                                        child: Center(
                                            child: Text(l10n.before,
                                                style: TextStyle(
                                                    color: AppTheme.textMuted,
                                                    fontSize: Responsive.font(
                                                        8, scale),
                                                    fontWeight:
                                                        FontWeight.w600))),
                                      ),
                                    ),
                                    Container(
                                        width: 1, color: AppTheme.borderStrong),
                                    Expanded(
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                            vertical: Responsive.pad(2, scale)),
                                        decoration: BoxDecoration(
                                            color: AppTheme.bgElevated
                                                .withValues(alpha: 0.5)),
                                        child: Center(
                                            child: Text(l10n.after,
                                                style: TextStyle(
                                                    color: AppTheme.textMuted,
                                                    fontSize: Responsive.font(
                                                        8, scale),
                                                    fontWeight:
                                                        FontWeight.w600))),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 1),
                                Expanded(
                                  child: _SideBySideDiff(
                                      oldContent: _oldContent,
                                      newContent: _newContent,
                                      scrollController: _scrollCtrl,
                                      scale: scale),
                                ),
                              ],
                            )
                      : _FileViewer(content: _newContent, scale: scale);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _FileSection extends StatelessWidget {
  final String title;
  final int count;
  final Color color;
  final List<GitFileChange> files;
  final GitFileChange? selected;
  final Set<String> selection;
  final ValueChanged<String> onToggle;
  final ValueChanged<GitFileChange> onSelect;
  final VoidCallback onSelectAll;
  final VoidCallback onDeselectAll;
  final String actionLabel;
  final IconData actionIcon;
  final ModernButtonVariant actionVariant;
  final VoidCallback onAction;
  final double scale;
  final ScrollController? scrollController;

  const _FileSection({
    required this.title,
    required this.count,
    required this.color,
    required this.files,
    required this.selected,
    required this.selection,
    required this.onToggle,
    required this.onSelect,
    required this.onSelectAll,
    required this.onDeselectAll,
    required this.actionLabel,
    required this.actionIcon,
    required this.actionVariant,
    required this.onAction,
    required this.scale,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgElevated.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: Responsive.pad(6, scale),
                vertical: Responsive.pad(3, scale)),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(4)),
            ),
            child: Row(
              children: [
                Text(title,
                    style: TextStyle(
                        color: color,
                        fontSize: Responsive.font(10, scale),
                        fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('$count',
                    style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: Responsive.font(10, scale),
                        fontWeight: FontWeight.w600)),
                SizedBox(width: Responsive.pad(4, scale)),
                if (files.isNotEmpty && selection.length < files.length)
                  InkWell(
                    onTap: onSelectAll,
                    child: Text(l10n.all,
                        style: TextStyle(
                            color: AppTheme.accent,
                            fontSize: Responsive.font(9, scale),
                            fontWeight: FontWeight.w600)),
                  ),
                if (files.isNotEmpty && selection.isNotEmpty)
                  InkWell(
                    onTap: onDeselectAll,
                    child: Padding(
                      padding: EdgeInsets.only(left: Responsive.pad(6, scale)),
                      child: Text(l10n.none,
                          style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: Responsive.font(9, scale),
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                SizedBox(width: Responsive.pad(6, scale)),
                ModernButton(
                  icon: actionIcon,
                  label: actionLabel,
                  variant: actionVariant,
                  tiny: true,
                  scale: scale,
                  onPressed: onAction,
                ),
              ],
            ),
          ),
          // List
          Expanded(
            child: files.isEmpty
                ? Center(
                    child: Text(l10n.empty,
                        style: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: Responsive.font(10, scale))))
                : ListView.builder(
                    controller: scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.all(Responsive.pad(2, scale)),
                    itemCount: files.length,
                    itemBuilder: (_, i) {
                        final change = files[i];
                        final isSel = selected?.path == change.path;
                        final isChecked = selection.contains(change.path);
                        return Material(
                          color: isSel
                              ? AppTheme.accent.withValues(alpha: 0.08)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(3),
                          child: InkWell(
                            onTap: () => onSelect(change),
                            borderRadius: BorderRadius.circular(3),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: Responsive.pad(4, scale),
                                  vertical: Responsive.pad(2, scale)),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: Responsive.icon(14, scale),
                                    height: Responsive.icon(14, scale),
                                    child: Transform.scale(
                                      scale: 0.7,
                                      child: Checkbox(
                                        value: isChecked,
                                        onChanged: (_) => onToggle(change.path),
                                        activeColor: AppTheme.accent,
                                        side: const BorderSide(
                                            color: AppTheme.textMuted,
                                            width: 1),
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: Responsive.pad(3, scale)),
                                  Expanded(
                                    child: Text(
                                      change.path,
                                      style: TextStyle(
                                        color: change.type == 'DELETED' ||
                                                change.type == 'CONFLICTING'
                                            ? Color(change.colorValue)
                                            : AppTheme.text,
                                        fontSize: Responsive.font(10, scale),
                                        fontFamily: 'monospace',
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                  SizedBox(width: Responsive.pad(3, scale)),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: Responsive.pad(3, scale),
                                        vertical: Responsive.pad(1, scale)),
                                    decoration: BoxDecoration(
                                      color: Color(change.colorValue)
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(100),
                                    ),
                                    child: Text(
                                      change.labelText(l10n),
                                      style: TextStyle(
                                          color: Color(change.colorValue),
                                          fontSize: Responsive.font(8, scale),
                                          fontWeight: FontWeight.bold),
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
        ],
      ),
    );
  }
}

class _CommitButton extends StatelessWidget {
  final VoidCallback onPressed;
  final double scale;
  final int stagedCount;
  const _CommitButton(
      {required this.onPressed, required this.scale, required this.stagedCount});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final enabled = stagedCount > 0;
    final button = Material(
      color: enabled ? AppTheme.success : AppTheme.success.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: Responsive.pad(8, scale),
              vertical: Responsive.pad(5, scale)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_rounded,
                  color: enabled ? Colors.white : Colors.white.withValues(alpha: 0.6),
                  size: Responsive.icon(14, scale)),
              SizedBox(width: Responsive.pad(3, scale)),
              Text(l10n.commit,
                  style: TextStyle(
                      color: enabled ? Colors.white : Colors.white.withValues(alpha: 0.6),
                      fontSize: Responsive.font(12, scale),
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
    if (enabled) return button;
    return Tooltip(
      message: l10n.commitButtonTooltipNoStagedFiles,
      child: button,
    );
  }
}

class _DiffTab extends StatelessWidget {
  final String label;
  final bool active;
  final double scale;
  final VoidCallback onTap;
  const _DiffTab(
      {required this.label,
      required this.active,
      required this.scale,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(
              horizontal: Responsive.pad(8, scale),
              vertical: Responsive.pad(3, scale)),
          decoration: BoxDecoration(
            color: active
                ? AppTheme.accent.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
                color: active
                    ? AppTheme.accent.withValues(alpha: 0.4)
                    : Colors.transparent),
          ),
          child: Text(
            label,
            style: TextStyle(
                color: active ? AppTheme.accentHover : AppTheme.textMuted,
                fontSize: Responsive.font(10, scale),
                fontWeight: active ? FontWeight.w600 : FontWeight.w500),
          ),
        ),
      ),
    );
  }
}

class _FileViewer extends StatelessWidget {
  final String content;
  final double scale;
  const _FileViewer({required this.content, required this.scale});

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
                padding: EdgeInsets.symmetric(
                    horizontal: Responsive.pad(6, scale),
                    vertical: Responsive.pad(1, scale)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: Responsive.pad(28, scale),
                      child: Text('${i + 1}',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              color: AppTheme.textMuted,
                              fontFamily: 'monospace',
                              fontSize: Responsive.font(8, scale))),
                    ),
                    SizedBox(width: Responsive.pad(4, scale)),
                    Expanded(
                      child: SelectableText(
                        lines[i],
                        style: TextStyle(
                            color: const Color(0xFFC9D1D9),
                            fontFamily: 'monospace',
                            fontSize: Responsive.font(10, scale),
                            height: 1.2),
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

class _SideBySideDiff extends StatefulWidget {
  final String oldContent;
  final String newContent;
  final ScrollController scrollController;
  final double scale;
  const _SideBySideDiff(
      {required this.oldContent,
      required this.newContent,
      required this.scrollController,
      required this.scale});

  @override
  State<_SideBySideDiff> createState() => _SideBySideDiffState();
}

class _SideBySideDiffState extends State<_SideBySideDiff> {
  late List<_DiffRow> _rows;

  @override
  void initState() {
    super.initState();
    _rows = _computeDiff(widget.oldContent, widget.newContent);
  }

  @override
  void didUpdateWidget(covariant _SideBySideDiff oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.oldContent != widget.oldContent ||
        oldWidget.newContent != widget.newContent) {
      _rows = _computeDiff(widget.oldContent, widget.newContent);
    }
  }

  List<_DiffRow> _computeDiff(String oldText, String newText) {
    final oldLines = oldText.split('\n');
    final newLines = newText.split('\n');
    final rows = <_DiffRow>[];
    int o = 0, n = 0;
    while (o < oldLines.length || n < newLines.length) {
      if (o < oldLines.length &&
          n < newLines.length &&
          oldLines[o] == newLines[n]) {
        rows.add(_DiffRow(
            leftLine: oldLines[o],
            rightLine: newLines[n],
            leftType: _LineType.normal,
            rightType: _LineType.normal,
            leftNum: o + 1,
            rightNum: n + 1));
        o++;
        n++;
      } else {
        int matchOld = -1, matchNew = -1;
        const maxLookAhead = 8;
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
          while (o < oldLines.length || n < newLines.length) {
            if (o < oldLines.length && n < newLines.length) {
              rows.add(_DiffRow(
                  leftLine: oldLines[o],
                  rightLine: newLines[n],
                  leftType: _LineType.removed,
                  rightType: _LineType.added,
                  leftNum: o + 1,
                  rightNum: n + 1));
              o++;
              n++;
            } else if (o < oldLines.length) {
              rows.add(_DiffRow(
                  leftLine: oldLines[o],
                  rightLine: null,
                  leftType: _LineType.removed,
                  rightType: _LineType.empty,
                  leftNum: o + 1,
                  rightNum: null));
              o++;
            } else {
              rows.add(_DiffRow(
                  leftLine: null,
                  rightLine: newLines[n],
                  leftType: _LineType.empty,
                  rightType: _LineType.added,
                  leftNum: null,
                  rightNum: n + 1));
              n++;
            }
          }
        } else {
          for (int i = 0; i < matchOld || i < matchNew; i++) {
            final oldLine = i < matchOld ? oldLines[o + i] : null;
            final newLine = i < matchNew ? newLines[n + i] : null;
            rows.add(_DiffRow(
                leftLine: oldLine,
                rightLine: newLine,
                leftType: oldLine != null ? _LineType.removed : _LineType.empty,
                rightType: newLine != null ? _LineType.added : _LineType.empty,
                leftNum: oldLine != null ? o + i + 1 : null,
                rightNum: newLine != null ? n + i + 1 : null));
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
          children: _rows
              .map((row) => _DiffRowWidget(row: row, scale: widget.scale))
              .toList(),
        ),
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
  _DiffRow(
      {required this.leftLine,
      required this.rightLine,
      required this.leftType,
      required this.rightType,
      required this.leftNum,
      required this.rightNum});
}

enum _LineType { normal, added, removed, empty }

class _DiffRowWidget extends StatelessWidget {
  final _DiffRow row;
  final double scale;
  const _DiffRowWidget({required this.row, required this.scale});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
              child: _LineCell(
                  line: row.leftLine,
                  lineNum: row.leftNum,
                  type: row.leftType,
                  scale: scale)),
          Container(
              width: 1, color: AppTheme.borderStrong.withValues(alpha: 0.3)),
          Expanded(
              child: _LineCell(
                  line: row.rightLine,
                  lineNum: row.rightNum,
                  type: row.rightType,
                  scale: scale)),
        ],
      ),
    );
  }
}

class _LineCell extends StatelessWidget {
  final String? line;
  final int? lineNum;
  final _LineType type;
  final double scale;
  const _LineCell(
      {required this.line,
      required this.lineNum,
      required this.type,
      required this.scale});

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
      padding: EdgeInsets.symmetric(vertical: Responsive.pad(1, scale)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: Responsive.pad(28, scale),
            child: Text(lineNum?.toString() ?? '',
                textAlign: TextAlign.right,
                style: TextStyle(
                    color: numColor,
                    fontFamily: 'monospace',
                    fontSize: Responsive.font(8, scale))),
          ),
          SizedBox(width: Responsive.pad(4, scale)),
          Expanded(
            child: SelectableText(
              line ?? '',
              style: TextStyle(
                  color: fg,
                  fontFamily: 'monospace',
                  fontSize: Responsive.font(10, scale),
                  height: 1.2),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnifiedDiff extends StatelessWidget {
  final String oldContent;
  final String newContent;
  final double scale;
  const _UnifiedDiff(
      {required this.oldContent,
      required this.newContent,
      required this.scale});

  @override
  Widget build(BuildContext context) {
    final oldLines = oldContent.split('\n');
    final newLines = newContent.split('\n');
    final rows = <Widget>[];
    int o = 0, n = 0;
    while (o < oldLines.length || n < newLines.length) {
      if (o < oldLines.length &&
          n < newLines.length &&
          oldLines[o] == newLines[n]) {
        rows.add(_UnifiedLine(
            line: oldLines[o],
            type: _LineType.normal,
            oldNum: o + 1,
            newNum: n + 1,
            scale: scale));
        o++;
        n++;
      } else {
        int matchOld = -1, matchNew = -1;
        const maxLookAhead = 8;
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
          while (o < oldLines.length || n < newLines.length) {
            if (o < oldLines.length && n < newLines.length) {
              rows.add(_UnifiedLine(
                  line: '- ${oldLines[o]}',
                  type: _LineType.removed,
                  oldNum: o + 1,
                  scale: scale));
              rows.add(_UnifiedLine(
                  line: '+ ${newLines[n]}',
                  type: _LineType.added,
                  newNum: n + 1,
                  scale: scale));
              o++;
              n++;
            } else if (o < oldLines.length) {
              rows.add(_UnifiedLine(
                  line: '- ${oldLines[o]}',
                  type: _LineType.removed,
                  oldNum: o + 1,
                  scale: scale));
              o++;
            } else {
              rows.add(_UnifiedLine(
                  line: '+ ${newLines[n]}',
                  type: _LineType.added,
                  newNum: n + 1,
                  scale: scale));
              n++;
            }
          }
        } else {
          for (int i = 0; i < matchOld; i++)
            rows.add(_UnifiedLine(
                line: '- ${oldLines[o + i]}',
                type: _LineType.removed,
                oldNum: o + i + 1,
                scale: scale));
          for (int j = 0; j < matchNew; j++)
            rows.add(_UnifiedLine(
                line: '+ ${newLines[n + j]}',
                type: _LineType.added,
                newNum: n + j + 1,
                scale: scale));
          o += matchOld;
          n += matchNew;
        }
      }
    }
    return Container(
      decoration: BoxDecoration(
          color: AppTheme.bgElevated, borderRadius: BorderRadius.circular(4)),
      child: ListView.builder(
        padding: EdgeInsets.all(Responsive.pad(4, scale)),
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
  final double scale;
  const _UnifiedLine(
      {required this.line,
      required this.type,
      this.oldNum,
      this.newNum,
      required this.scale});

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
      padding: EdgeInsets.symmetric(
          vertical: Responsive.pad(1, scale),
          horizontal: Responsive.pad(3, scale)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: Responsive.pad(24, scale),
              child: Text(oldNum?.toString() ?? '',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      color: const Color(0xFF5E6A7A),
                      fontFamily: 'monospace',
                      fontSize: Responsive.font(8, scale)))),
          SizedBox(width: Responsive.pad(3, scale)),
          SizedBox(
              width: Responsive.pad(24, scale),
              child: Text(newNum?.toString() ?? '',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      color: const Color(0xFF5E6A7A),
                      fontFamily: 'monospace',
                      fontSize: Responsive.font(8, scale)))),
          SizedBox(width: Responsive.pad(4, scale)),
          Expanded(
              child: SelectableText(line,
                  style: TextStyle(
                      color: fg,
                      fontFamily: 'monospace',
                      fontSize: Responsive.font(10, scale),
                      height: 1.2))),
        ],
      ),
    );
  }
}
