import 'package:flutter/material.dart';
import '../models/git_project.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/modern_card.dart';
import 'staging_screen.dart';
import 'timeline_screen.dart';

class ProjectDetailScreen extends StatefulWidget {
  final GitProject project;
  final ApiService api;
  final bool inline;

  const ProjectDetailScreen({
    super.key,
    required this.project,
    required this.api,
    this.inline = false,
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
  List<String> _commits = [];
  List<String> _tags = [];
  List<String> _stashes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 5, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _outputCtrl.dispose();
    _branchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final branches = await widget.api.getBranches(widget.project.path);
      final commits = await widget.api.getCommits(widget.project.path);
      final tags = await widget.api.getTags(widget.project.path);
      final stashes = await widget.api.getStashes(widget.project.path);
      setState(() {
        _branches = branches.map((b) => b.name).toList();
        _currentBranch = branches.isEmpty
            ? null
            : branches.firstWhere((b) => b.head, orElse: () => branches.first).name;
        _commits = commits;
        _tags = tags;
        _stashes = stashes;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _log('Erro ao carregar dados: $e');
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
    } catch (e) {
      _log('❌ Erro: $e');
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
        title: Text('Credenciais — $operation', style: const TextStyle(color: AppTheme.text)),
        content: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: userCtrl,
                style: const TextStyle(color: AppTheme.text),
                decoration: const InputDecoration(labelText: 'Usuário (opcional)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passCtrl,
                obscureText: true,
                style: const TextStyle(color: AppTheme.text),
                decoration: const InputDecoration(labelText: 'Senha/Token (opcional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
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
            child: const Text('Executar'),
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (ctrl.text.isNotEmpty) onConfirm(ctrl.text.trim());
            },
            child: const Text('Confirmar'),
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
                  tooltip: 'Atualizar',
                ),
              ],
            ),
          ),
        TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(icon: Icon(Icons.code, size: 20), text: 'Visão Geral'),
            Tab(icon: Icon(Icons.edit_note, size: 20), text: 'Commit'),
            Tab(icon: Icon(Icons.history, size: 20), text: 'Histórico'),
            Tab(icon: Icon(Icons.label_outline, size: 20), text: 'Tags'),
            Tab(icon: Icon(Icons.archive_outlined, size: 20), text: 'Stash'),
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
          tabs: const [
            Tab(icon: Icon(Icons.code, size: 20), text: 'Visão Geral'),
            Tab(icon: Icon(Icons.edit_note, size: 20), text: 'Commit'),
            Tab(icon: Icon(Icons.history, size: 20), text: 'Histórico'),
            Tab(icon: Icon(Icons.label_outline, size: 20), text: 'Tags'),
            Tab(icon: Icon(Icons.archive_outlined, size: 20), text: 'Stash'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Atualizar',
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
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info header
            ModernCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle(Icons.account_tree_outlined, 'Branch Atual'),
                        const SizedBox(height: 8),
                        Text(
                          _currentBranch ?? 'N/A',
                          style: const TextStyle(
                            color: AppTheme.text,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 50,
                    color: AppTheme.borderStrong,
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle(Icons.commit, 'HEAD'),
                        const SizedBox(height: 8),
                        FutureBuilder(
                          future: widget.api.getStatus(widget.project.path),
                          builder: (context, snapshot) {
                            final head = snapshot.data?['head'] ?? '';
                            return Text(
                              head.isNotEmpty ? head.substring(0, 7) : '---',
                              style: const TextStyle(
                                color: AppTheme.text,
                                fontSize: 16,
                                fontFamily: 'monospace',
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            // Branch control
            ModernCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle(Icons.swap_horiz, 'Trocar Branch'),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 500;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            width: isWide ? 240 : double.infinity,
                            child: DropdownButtonFormField<String>(
                              value: _currentBranch,
                              dropdownColor: AppTheme.bgElevated,
                              style: const TextStyle(color: AppTheme.text),
                              decoration: const InputDecoration(
                                labelText: 'Selecionar branch',
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                          _actionButton(
                            icon: Icons.check_circle_outline,
                            label: 'Checkout',
                            color: AppTheme.accent,
                            onPressed: () {
                              if (_currentBranch != null) {
                                _runAsync(() => widget.api.checkout(widget.project.path, _currentBranch!));
                              }
                            },
                          ),
                          _actionButton(
                            icon: Icons.add,
                            label: 'Nova',
                            color: AppTheme.success,
                            onPressed: () => _showInputDialog('Nova Branch', 'Nome da branch', (name) {
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
            const SizedBox(height: 18),
            // Sync
            ModernCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle(Icons.sync_outlined, 'Sincronização'),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _actionButton(
                        icon: Icons.arrow_upward,
                        label: 'Push',
                        color: AppTheme.accent,
                        onPressed: () => _showCredsDialog('Push'),
                      ),
                      _actionButton(
                        icon: Icons.arrow_downward,
                        label: 'Pull',
                        color: AppTheme.success,
                        onPressed: () => _showCredsDialog('Pull'),
                      ),
                      _actionButton(
                        icon: Icons.sync,
                        label: 'Fetch',
                        color: AppTheme.info,
                        onPressed: () => _showCredsDialog('Fetch'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            // Output
            ModernCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _sectionTitle(Icons.terminal, 'Saída'),
                      const Spacer(),
                      TextButton(
                        onPressed: () => _outputCtrl.clear(),
                        child: const Text('Limpar'),
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
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: ModernCard(
          child: StagingScreen(
            path: widget.project.path,
            api: widget.api,
            onLog: _log,
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ModernCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle(Icons.history, 'Commits Recentes'),
                const SizedBox(height: 12),
                SizedBox(
                  height: 240,
                  child: _commits.isEmpty
                      ? const Center(
                          child: Text('Nenhum commit', style: TextStyle(color: AppTheme.textMuted)),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: _commits.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            return ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                              leading: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: AppTheme.accent.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.commit, size: 14, color: AppTheme.accent),
                              ),
                              title: Text(
                                _commits[i],
                                style: const TextStyle(
                                  color: AppTheme.text,
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle(Icons.account_tree, 'Timeline Gráfica'),
                const SizedBox(height: 12),
                Flexible(
                  fit: FlexFit.loose,
                  child: TimelineScreen(
                    path: widget.project.path,
                    api: widget.api,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagsTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _actionButton(
            icon: Icons.add,
            label: 'Nova Tag',
            color: AppTheme.accent,
            onPressed: () => _showInputDialog('Nova Tag', 'Nome da tag', (name) {
              _showInputDialog('Mensagem da Tag', 'Mensagem (opcional)', (msg) {
                _runAsync(() => widget.api.createTag(widget.project.path, name, msg));
              });
            }),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _tags.isEmpty
                ? const Center(child: Text('Nenhuma tag', style: TextStyle(color: AppTheme.textMuted)))
                : ListView.builder(
                    itemCount: _tags.length,
                    itemBuilder: (_, i) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ModernCard(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              const Icon(Icons.label_outline, color: AppTheme.accent, size: 18),
                              const SizedBox(width: 12),
                              Text(_tags[i], style: const TextStyle(color: AppTheme.text, fontSize: 14)),
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
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _actionButton(
                icon: Icons.add,
                label: 'Salvar Stash',
                color: AppTheme.accent,
                onPressed: () => _showInputDialog('Salvar Stash', 'Mensagem (opcional)', (msg) {
                  _runAsync(() => widget.api.stashSave(widget.project.path, msg));
                }),
              ),
              _actionButton(
                icon: Icons.download_outlined,
                label: 'Aplicar',
                color: AppTheme.info,
                onPressed: () => _runAsync(() => widget.api.stashApply(widget.project.path, 0)),
              ),
              _actionButton(
                icon: Icons.archive_outlined,
                label: 'Pop',
                color: AppTheme.success,
                onPressed: () => _runAsync(() => widget.api.stashPop(widget.project.path, 0)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _stashes.isEmpty
                ? const Center(child: Text('Nenhum stash', style: TextStyle(color: AppTheme.textMuted)))
                : ListView.builder(
                    itemCount: _stashes.length,
                    itemBuilder: (_, i) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ModernCard(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: AppTheme.warning.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.archive_outlined, size: 14, color: AppTheme.warning),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _stashes[i],
                                  style: const TextStyle(color: AppTheme.text, fontSize: 13),
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

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


