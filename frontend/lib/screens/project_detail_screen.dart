import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:git_manager_ui/generated/l10n/app_localizations.dart';
import '../models/git_project.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/modern_button.dart';
import '../widgets/modern_card.dart';
import '../widgets/modern_dialog.dart';
import '../widgets/ssh_setup_dialog.dart';
import 'merge_screen.dart';
import 'staging_screen.dart';
import 'timeline_screen.dart';

class ProjectDetailScreen extends StatefulWidget {
  final GitProject project;
  final ApiService api;
  final bool inline;
  final ValueChanged<GitProject>? onProjectChanged;

  const ProjectDetailScreen({
    super.key,
    required this.project,
    required this.api,
    this.inline = false,
    this.onProjectChanged,
  });

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _outputCtrl = TextEditingController();
  final _branchCtrl = TextEditingController();
  List<String> _branches = [];
  String? _currentBranch;
  List<String> _tags = [];
  List<String> _stashes = [];
  bool _loading = true;
  int _syncAhead = 0;
  int _syncBehind = 0;
  bool _hasRemote = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 6, vsync: this);
    _loadData();
    _refreshStatus();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _refreshAll();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabCtrl.dispose();
    _outputCtrl.dispose();
    _branchCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshStatus() async {
    try {
      final sync = await widget.api.getSyncStatus(widget.project.path);
      if (mounted) {
        setState(() {
          _syncAhead = (sync['ahead'] as num?)?.toInt() ?? 0;
          _syncBehind = (sync['behind'] as num?)?.toInt() ?? 0;
          _hasRemote = sync['hasRemote'] == true;
        });
      }
    } catch (e) {
      // Silently fail on background refresh
    }
  }

  Future<void> _refreshAll() async {
    await _refreshStatus();
    try {
      final branches = await widget.api.getBranches(widget.project.path);
      final tags = await widget.api.getTags(widget.project.path);
      final stashes = await widget.api.getStashes(widget.project.path);
      if (mounted) {
        setState(() {
          _branches = branches.map((b) => b.name).toList();
          _currentBranch = branches.isEmpty
              ? (widget.project.currentBranch.isNotEmpty ? widget.project.currentBranch : null)
              : branches.firstWhere((b) => b.head, orElse: () => branches.first).name;
          _tags = tags;
          _stashes = stashes;
        });
      }
    } catch (e) {
      // Silently fail on background refresh
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final branches = await widget.api.getBranches(widget.project.path);
      final tags = await widget.api.getTags(widget.project.path);
      final stashes = await widget.api.getStashes(widget.project.path);
      setState(() {
        _branches = branches.map((b) => b.name).toList();
        _currentBranch = branches.isEmpty
            ? (widget.project.currentBranch.isNotEmpty ? widget.project.currentBranch : null)
            : branches.firstWhere((b) => b.head, orElse: () => branches.first).name;
        _tags = tags;
        _stashes = stashes;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _log('${AppLocalizations.of(context)!.errorLoadingData}: $e');
    }
  }

  void _log(String msg) {
    setState(() {
      _outputCtrl.text += '$msg\n';
    });
  }

  Future<void> _runAsync(Future<String> Function() action) async {
    _log('⏳ Executando...');
    try {
      final result = await action();
      _log(result);
      await _loadData();
      if (result.contains('Permission denied') || result.contains('publickey') || result.contains('Cannot log in')) {
        if (mounted) {
          _log('💡 Dica: configure sua chave SSH clicando no ícone de chave 🔑 no topo da barra lateral.');
        }
      }
    } catch (e) {
      final msg = e.toString();
      _log('❌ Erro: $msg');
      if (msg.contains('Permission denied') || msg.contains('publickey') || msg.contains('Cannot log in')) {
        if (mounted) {
          SshSetupDialog.show(context, widget.api);
        }
      }
    }
  }

  void _showCredsDialog(String operation) {
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('${AppLocalizations.of(context)!.credentials} — $operation', style: const TextStyle(color: AppTheme.text)),
        content: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: userCtrl,
                style: const TextStyle(color: AppTheme.text),
                decoration: InputDecoration(labelText: AppLocalizations.of(context)!.userOptional),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passCtrl,
                obscureText: true,
                style: const TextStyle(color: AppTheme.text),
                decoration: InputDecoration(labelText: AppLocalizations.of(context)!.passwordOptional),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.of(context)!.cancel)),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              final user = userCtrl.text.isEmpty ? null : userCtrl.text;
              final pass = passCtrl.text.isEmpty ? null : passCtrl.text;
              switch (operation) {
                case 'Push':
                  _runAsync(() => widget.api.push(widget.project.path, username: user, password: pass));
                  break;
                case 'Pull':
                  _runAsync(() => widget.api.pull(widget.project.path, username: user, password: pass));
                  break;
                case 'Fetch':
                  _runAsync(() => widget.api.fetch(widget.project.path, username: user, password: pass));
                  break;
              }
            },
            child: Text(AppLocalizations.of(context)!.execute),
          ),
        ],
      ),
    );
  }

  void _showInputDialog(String title, String label, Function(String) onConfirm) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(color: AppTheme.text)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: AppTheme.text),
          decoration: InputDecoration(labelText: label),
          onSubmitted: (v) {
            Navigator.pop(ctx);
            if (v.isNotEmpty) onConfirm(v.trim());
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.of(context)!.cancel)),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (ctrl.text.isNotEmpty) onConfirm(ctrl.text.trim());
            },
            child: Text(AppLocalizations.of(context)!.confirm),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.accent));
    }

    final content = Column(
      children: [
        if (widget.inline)
          Container(
            color: AppTheme.bgElevated,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.project.name,
                        style: const TextStyle(
                          color: AppTheme.text,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        widget.project.path,
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: AppTheme.textMuted, size: 20),
                  onPressed: _loadData,
                  tooltip: AppLocalizations.of(context)!.refresh,
                ),
              ],
            ),
          ),
        TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(icon: const Icon(Icons.code, size: 20), text: AppLocalizations.of(context)!.overview),
            Tab(icon: const Icon(Icons.edit_note, size: 20), text: AppLocalizations.of(context)!.commit),
            Tab(icon: const Icon(Icons.history, size: 20), text: AppLocalizations.of(context)!.history),
            Tab(icon: const Icon(Icons.label_outline, size: 20), text: AppLocalizations.of(context)!.tags),
            Tab(icon: const Icon(Icons.archive_outlined, size: 20), text: AppLocalizations.of(context)!.stash),
            Tab(icon: const Icon(Icons.call_merge, size: 20), text: 'Merge'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _buildOverviewTab(),
              _buildCommitTab(),
              _buildHistoryTab(),
              _buildTagsTab(),
              _buildStashTab(),
              _buildMergeTab(),
            ],
          ),
        ),
      ],
    );

    if (widget.inline) {
      return content;
    }

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bgElevated,
        elevation: 0,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.project.name, overflow: TextOverflow.ellipsis),
              Text(
                widget.project.path,
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(icon: const Icon(Icons.code, size: 20), text: AppLocalizations.of(context)!.overview),
            Tab(icon: const Icon(Icons.edit_note, size: 20), text: AppLocalizations.of(context)!.commit),
            Tab(icon: const Icon(Icons.history, size: 20), text: AppLocalizations.of(context)!.history),
            Tab(icon: const Icon(Icons.label_outline, size: 20), text: AppLocalizations.of(context)!.tags),
            Tab(icon: const Icon(Icons.archive_outlined, size: 20), text: AppLocalizations.of(context)!.stash),
            Tab(icon: const Icon(Icons.call_merge, size: 20), text: 'Merge'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => SshSetupDialog.show(context, widget.api),
            child: const Text('SSH', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: AppLocalizations.of(context)!.refresh,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildOverviewTab(),
          _buildCommitTab(),
          _buildHistoryTab(),
          _buildTagsTab(),
          _buildStashTab(),
          _buildMergeTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info header
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 500;
                return ModernCard(
                  child: isNarrow
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionTitle(Icons.account_tree_outlined, AppLocalizations.of(context)!.currentBranch),
                            const SizedBox(height: 8),
                            Text(
                              _currentBranch ?? AppLocalizations.of(context)!.unavailable,
                              style: const TextStyle(color: AppTheme.text, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            const Divider(height: 1),
                            const SizedBox(height: 16),
                            _sectionTitle(Icons.commit, AppLocalizations.of(context)!.head),
                            const SizedBox(height: 8),
                            FutureBuilder(
                              future: widget.api.getStatus(widget.project.path),
                              builder: (context, snapshot) {
                                final head = snapshot.data?['head'] ?? '';
                                return Text(
                                  head.isNotEmpty ? head.substring(0, 7) : '---',
                                  style: const TextStyle(color: AppTheme.text, fontSize: 16, fontFamily: 'monospace'),
                                );
                              },
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _sectionTitle(Icons.account_tree_outlined, AppLocalizations.of(context)!.currentBranch),
                                  const SizedBox(height: 8),
                                  Text(
                                    _currentBranch ?? AppLocalizations.of(context)!.unavailable,
                                    style: const TextStyle(color: AppTheme.text, fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            Container(width: 1, height: 50, color: AppTheme.borderStrong),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _sectionTitle(Icons.commit, AppLocalizations.of(context)!.head),
                                  const SizedBox(height: 8),
                                  FutureBuilder(
                                    future: widget.api.getStatus(widget.project.path),
                                    builder: (context, snapshot) {
                                      final head = snapshot.data?['head'] ?? '';
                                      return Text(
                                        head.isNotEmpty ? head.substring(0, 7) : '---',
                                        style: const TextStyle(color: AppTheme.text, fontSize: 16, fontFamily: 'monospace'),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                );
              },
            ),
            const SizedBox(height: 12),
            // Branch control
            ModernCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle(Icons.swap_horiz, AppLocalizations.of(context)!.switchBranch),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 500;
                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            width: isWide ? 220 : double.infinity,
                            child: DropdownButtonFormField<String>(
                              value: _currentBranch,
                              dropdownColor: AppTheme.bgElevated,
                              style: const TextStyle(color: AppTheme.text),
                              decoration: InputDecoration(
                                labelText: AppLocalizations.of(context)!.selectBranch,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                isDense: true,
                              ),
                              items: _branches.map((b) {
                                return DropdownMenuItem(
                                  value: b,
                                  child: Text(b, style: const TextStyle(color: AppTheme.text)),
                                );
                              }).toList(),
                              onChanged: (v) => setState(() => _currentBranch = v),
                            ),
                          ),
                          ModernButton(
                            icon: Icons.check_circle_outline,
                            label: AppLocalizations.of(context)!.checkout,
                            variant: ModernButtonVariant.primary,
                            compact: true,
                            tooltip: AppLocalizations.of(context)!.infoTooltipCheckout,
                            onPressed: () {
                              if (_currentBranch != null) {
                                _runAsync(() => widget.api.checkout(widget.project.path, _currentBranch!));
                              }
                            },
                          ),
                          ModernButton(
                            icon: Icons.add,
                            label: AppLocalizations.of(context)!.newBranch,
                            variant: ModernButtonVariant.success,
                            compact: true,
                            tooltip: AppLocalizations.of(context)!.infoTooltipNewBranch,
                            onPressed: () => _showInputDialog(AppLocalizations.of(context)!.newBranch, AppLocalizations.of(context)!.branchName, (name) {
                              _runAsync(() => widget.api.createBranch(widget.project.path, name));
                            }),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Sync
            ModernCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _sectionTitle(Icons.sync_outlined, AppLocalizations.of(context)!.sync),
                      const Spacer(),
                      if (_hasRemote) ...[
                        if (_syncAhead == 0 && _syncBehind == 0)
                          Text(
                            AppLocalizations.of(context)!.upToDate,
                            style: const TextStyle(color: AppTheme.success, fontSize: 11, fontWeight: FontWeight.w600),
                          )
                        else
                          Text(
                            '${_syncAhead > 0 ? '+$_syncAhead ' : ''}${_syncBehind > 0 ? '-$_syncBehind' : ''}',
                            style: const TextStyle(color: AppTheme.warning, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                      ] else
                        Text(
                          AppLocalizations.of(context)!.noRemoteConfigured,
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.start,
                    children: [
                      ModernButton(
                        icon: Icons.arrow_upward,
                        label: AppLocalizations.of(context)!.push,
                        variant: ModernButtonVariant.primary,
                        compact: true,
                        disabled: !_hasRemote || _syncAhead <= 0,
                        tooltip: !_hasRemote
                            ? AppLocalizations.of(context)!.noRemoteConfigured
                            : _syncAhead <= 0
                                ? AppLocalizations.of(context)!.nothingToPush
                                : AppLocalizations.of(context)!.infoTooltipPush,
                        onPressed: () => _runAsync(() => widget.api.push(widget.project.path)),
                      ),
                      ModernButton(
                        icon: Icons.arrow_downward,
                        label: AppLocalizations.of(context)!.pull,
                        variant: ModernButtonVariant.success,
                        compact: true,
                        disabled: !_hasRemote || _syncBehind <= 0,
                        tooltip: !_hasRemote
                            ? AppLocalizations.of(context)!.noRemoteConfigured
                            : _syncBehind <= 0
                                ? AppLocalizations.of(context)!.nothingToPull
                                : AppLocalizations.of(context)!.infoTooltipPull,
                        onPressed: () => _runAsync(() => widget.api.pull(widget.project.path)),
                      ),
                      ModernButton(
                        icon: Icons.sync,
                        label: AppLocalizations.of(context)!.fetch,
                        variant: ModernButtonVariant.info,
                        compact: true,
                        disabled: !_hasRemote,
                        tooltip: !_hasRemote
                            ? AppLocalizations.of(context)!.noRemoteConfigured
                            : AppLocalizations.of(context)!.infoTooltipFetch,
                        onPressed: () => _runAsync(() => widget.api.fetch(widget.project.path)),
                      ),
                      ModernButton(
                        icon: Icons.key,
                        label: 'SSH',
                        variant: ModernButtonVariant.ghost,
                        compact: true,
                        tooltip: 'Configurar chave SSH',
                        onPressed: () => SshSetupDialog.show(context, widget.api),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Output
            ModernCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _sectionTitle(Icons.terminal, AppLocalizations.of(context)!.output),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18, color: AppTheme.textMuted),
                        tooltip: AppLocalizations.of(context)!.copy,
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _outputCtrl.text));
                        },
                      ),
                      TextButton(
                        onPressed: () => _outputCtrl.clear(),
                        child: Text(AppLocalizations.of(context)!.clear),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 200,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C0E12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderStrong),
                    ),
                    child: TextField(
                      controller: _outputCtrl,
                      style: const TextStyle(
                        color: Color(0xFFC9D1D9),
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                      maxLines: null,
                      expands: true,
                      readOnly: true,
                      decoration: const InputDecoration.collapsed(hintText: ''),
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

  Widget _buildCommitTab() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: StagingScreen(
        path: widget.project.path,
        api: widget.api,
        onLog: _log,
      ),
    );
  }

  Widget _buildHistoryTab() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Branch commits
          ModernCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _sectionTitle(Icons.history, l10n.branchCommits),
                    const Spacer(),
                    if (_currentBranch != null)
                      _BranchChip(name: _currentBranch!, color: AppTheme.accent),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 160,
                  child: FutureBuilder(
                    future: widget.api.getCommitGraph(widget.project.path),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent)));
                      }
                      final allCommits = snapshot.data!;
                      final branchCommits = _currentBranch == null
                          ? allCommits
                          : allCommits.where((c) => c.branchNames.any((b) => b.contains(_currentBranch!))).toList();
                      if (branchCommits.isEmpty) {
                        return Center(child: Text(l10n.noCommitsToShow, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)));
                      }
                      return ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: branchCommits.length.clamp(0, 12),
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final c = branchCommits[i];
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            minLeadingWidth: 20,
                            leading: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: AppTheme.accent.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.commit, size: 12, color: AppTheme.accent),
                            ),
                            title: Text(
                              c.message,
                              style: const TextStyle(color: AppTheme.text, fontSize: 12, fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${c.shortId}  ·  ${c.authorName}  ·  ${_fmtDate(c.commitTime)}',
                              style: const TextStyle(color: AppTheme.textMuted, fontFamily: 'monospace', fontSize: 10),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Timeline (all branches, no card)
          Expanded(
            child: TimelineScreen(
              path: widget.project.path,
              api: widget.api,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagsTab() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ModernButton(
            icon: Icons.add,
            label: l10n.newTag,
            variant: ModernButtonVariant.primary,
            compact: true,
            tooltip: l10n.infoTooltipNewTag,
            onPressed: () => _showInputDialog(l10n.newTag, l10n.tagName, (name) {
              _showInputDialog(l10n.tagMessage, 'Mensagem (opcional)', (msg) {
                _runAsync(() => widget.api.createTag(widget.project.path, name, msg));
              });
            }),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _tags.isEmpty
                ? Center(child: Text(l10n.noTags, style: const TextStyle(color: AppTheme.textMuted)))
                : ListView.builder(
                    itemCount: _tags.length,
                    padding: EdgeInsets.zero,
                    itemBuilder: (_, i) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: ModernCard(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              const Icon(Icons.label_outline, color: AppTheme.accent, size: 16),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(_tags[i], style: const TextStyle(color: AppTheme.text, fontSize: 13)),
                              ),
                              ModernButton(
                                icon: Icons.delete_outline,
                                variant: ModernButtonVariant.danger,
                                tiny: true,
                                tooltip: l10n.deleteTag,
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) => ModernConfirmDialog(
                                      title: l10n.deleteTag,
                                      message: l10n.deleteTagConfirm(_tags[i]),
                                      confirmLabel: l10n.delete,
                                      cancelLabel: l10n.cancel,
                                      confirmVariant: ModernButtonVariant.danger,
                                      icon: Icons.delete_outline,
                                      onConfirm: () => _runAsync(() => widget.api.deleteTag(widget.project.path, _tags[i])),
                                    ),
                                  );
                                },
                              ),
                            ],
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

  Widget _buildStashTab() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ModernButton(
                icon: Icons.add,
                label: l10n.saveStash,
                variant: ModernButtonVariant.primary,
                compact: true,
                tooltip: l10n.infoTooltipStashSave,
                onPressed: () => _showInputDialog(l10n.saveStash, 'Mensagem (opcional)', (msg) {
                  _runAsync(() => widget.api.stashSave(widget.project.path, msg));
                }),
              ),
              ModernButton(
                icon: Icons.download_outlined,
                label: l10n.apply,
                variant: ModernButtonVariant.info,
                compact: true,
                tooltip: l10n.infoTooltipStashApply,
                onPressed: () => _runAsync(() => widget.api.stashApply(widget.project.path, 0)),
              ),
              ModernButton(
                icon: Icons.archive_outlined,
                label: l10n.pop,
                variant: ModernButtonVariant.success,
                compact: true,
                tooltip: l10n.infoTooltipStashPop,
                onPressed: () => _runAsync(() => widget.api.stashPop(widget.project.path, 0)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _stashes.isEmpty
                ? Center(child: Text(l10n.noStash, style: const TextStyle(color: AppTheme.textMuted)))
                : ListView.builder(
                    itemCount: _stashes.length,
                    padding: EdgeInsets.zero,
                    itemBuilder: (_, i) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: ModernCard(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: AppTheme.warning.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.archive_outlined, size: 12, color: AppTheme.warning),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _stashes[i],
                                  style: const TextStyle(color: AppTheme.text, fontSize: 12),
                                ),
                              ),
                            ],
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

  Widget _buildMergeTab() {
    return MergeScreen(
      path: widget.project.path,
      api: widget.api,
      branches: _branches,
      currentBranch: _currentBranch,
      onLog: _log,
    );
  }

  Widget _sectionTitle(IconData icon, String title) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppTheme.accent),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.text,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // REMOVED: _actionButton replaced by ModernButton throughout
}

// ------------------------------------------------------------------
// Helpers
// ------------------------------------------------------------------
String _fmtDate(DateTime dt) {
  return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}'
      ' ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class _BranchChip extends StatelessWidget {
  final String name;
  final Color color;

  const _BranchChip({required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        name,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}


