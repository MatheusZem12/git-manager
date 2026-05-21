import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import '../models/git_project.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/modern_card.dart';
import '../widgets/status_badge.dart';
import '../widgets/glass_container.dart';
import 'project_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _api = ApiService();
  List<GitProject> _projects = [];
  List<GitProject> _filtered = [];
  bool _loading = true;
  String _search = '';
  GitProject? _selectedProject;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() => _loading = true);
    try {
      final projects = await _api.getProjects();
      setState(() {
        _projects = projects;
        _applyFilter();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _showError('Erro ao carregar projetos: $e');
    }
  }

  void _applyFilter() {
    if (_search.isEmpty) {
      _filtered = List.from(_projects);
    } else {
      final lower = _search.toLowerCase();
      _filtered = _projects.where((p) {
        return p.name.toLowerCase().contains(lower) ||
            p.path.toLowerCase().contains(lower);
      }).toList();
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showAddDialog() {
    final nameCtrl = TextEditingController();
    final pathCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Adicionar Repositório',
          style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: AppTheme.text),
                decoration: const InputDecoration(
                  labelText: 'Nome do projeto',
                  prefixIcon: Icon(Icons.folder_outlined),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: pathCtrl,
                      style: const TextStyle(color: AppTheme.text),
                      decoration: const InputDecoration(
                        labelText: 'Caminho absoluto',
                        prefixIcon: Icon(Icons.folder_open_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final dir = await getDirectoryPath();
                      if (dir != null) {
                        pathCtrl.text = dir;
                      }
                    },
                    icon: const Icon(Icons.folder_copy_outlined, size: 18),
                    label: const Text('Procurar'),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty || pathCtrl.text.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await _api.addProject(nameCtrl.text.trim(), pathCtrl.text.trim());
                await _loadProjects();
              } catch (e) {
                _showError(e.toString());
              }
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(GitProject project) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Remover Repositório',
          style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Remover "${project.name}" da lista?\n\nO diretório no disco não será alterado.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () async {
              Navigator.pop(ctx);
              await _api.deleteProject(project.path);
              if (_selectedProject?.path == project.path) {
                setState(() => _selectedProject = null);
              }
              await _loadProjects();
            },
            child: const Text('Remover'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final available = _projects.where((p) => p.isAvailable).length;
    final withChanges = _projects.where((p) => p.isAvailable && p.statusSummary != 'Limpo').length;
    final unavailable = _projects.length - available;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 900;
          return Row(
            children: [
              // Sidebar
              Container(
                width: isWide ? 340 : 280,
                decoration: BoxDecoration(
                  color: AppTheme.bgElevated,
                  border: Border(
                    right: BorderSide(color: AppTheme.borderStrong.withValues(alpha: 0.3)),
                  ),
                ),
                child: Column(
                  children: [
                    // Header
                    GlassContainer(
                      padding: const EdgeInsets.all(20),
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.accent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.folder_copy_outlined,
                                  color: AppTheme.accent,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Git Manager',
                                  style: TextStyle(
                                    color: AppTheme.text,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.refresh, color: AppTheme.textMuted, size: 20),
                                onPressed: _loadProjects,
                                tooltip: 'Atualizar',
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Search
                          TextField(
                            onChanged: (v) {
                              setState(() {
                                _search = v;
                                _applyFilter();
                              });
                            },
                            style: const TextStyle(color: AppTheme.text),
                            decoration: InputDecoration(
                              hintText: 'Buscar repositório...',
                              prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted),
                              suffixIcon: _search.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, color: AppTheme.textMuted, size: 18),
                                      onPressed: () {
                                        setState(() {
                                          _search = '';
                                          _applyFilter();
                                        });
                                      },
                                    )
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Stats
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _statItem(_projects.length.toString(), 'TOTAL', AppTheme.text),
                          _statItem(available.toString(), 'OK', AppTheme.success),
                          _statItem(withChanges.toString(), 'ALT', AppTheme.warning),
                          _statItem(
                            unavailable.toString(),
                            'INDISP.',
                            unavailable > 0 ? AppTheme.danger : AppTheme.textMuted,
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // List
                    Expanded(
                      child: _loading
                          ? const Center(
                              child: CircularProgressIndicator(color: AppTheme.accent),
                            )
                          : _filtered.isEmpty
                              ? const _EmptyState()
                              : Scrollbar(
                                  child: ListView.builder(
                                    padding: const EdgeInsets.all(12),
                                    itemCount: _filtered.length,
                                    itemBuilder: (context, index) {
                                      final project = _filtered[index];
                                      final isSelected = _selectedProject?.path == project.path;
                                      return _ProjectCard(
                                        project: project,
                                        isSelected: isSelected,
                                        onTap: () => setState(() => _selectedProject = project),
                                        onDelete: () => _confirmDelete(project),
                                      );
                                    },
                                  ),
                                ),
                    ),
                    // Botão Adicionar Repositório (na sidebar, não flutuante)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.bgElevated,
                        border: Border(
                          top: BorderSide(color: AppTheme.borderStrong.withValues(alpha: 0.3)),
                        ),
                      ),
                      child: _AddRepoButton(onTap: _showAddDialog),
                    ),
                  ],
                ),
              ),
              // Detail area
              Expanded(
                child: Container(
                  color: AppTheme.bg,
                  child: _selectedProject == null
                      ? const _WelcomeArea()
                      : ProjectDetailScreen(
                          project: _selectedProject!,
                          api: _api,
                          inline: true,
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _statItem(String value, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _AddRepoButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddRepoButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderStrong.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_rounded, color: AppTheme.text, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Adicionar Repositório',
                style: TextStyle(
                  color: AppTheme.text,
                  fontSize: 14,
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: AppTheme.textMuted.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          const Text(
            'Nenhum repositório',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 15, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            'Use o botão abaixo para cadastrar um diretório git.',
            style: TextStyle(color: AppTheme.textMuted.withValues(alpha: 0.6), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _WelcomeArea extends StatelessWidget {
  const _WelcomeArea();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surface.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.account_tree_outlined,
              size: 64,
              color: AppTheme.textMuted.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Selecione um repositório',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Clique em um item da lista para ver detalhes\ne executar operações Git.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textMuted.withValues(alpha: 0.6),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final GitProject project;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ProjectCard({
    required this.project,
    required this.isSelected,
    required this.onTap,
    required this.onDelete,
  });

  StatusBadge _buildBadge() {
    if (!project.isAvailable) return StatusBadge.error('OFF');
    if (project.statusSummary == 'Limpo') return StatusBadge.ok();
    if (project.statusSummary.contains('alteração')) {
      return StatusBadge.warn(project.statusSummary);
    }
    return StatusBadge.neutral(project.statusSummary);
  }

  Color _dotColor() {
    if (!project.existsOnDisk) return AppTheme.danger;
    if (!project.hasGit) return AppTheme.warning;
    return AppTheme.success;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ModernCard(
        onTap: onTap,
        color: isSelected ? AppTheme.surfaceActive : null,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: _dotColor(),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _dotColor().withValues(alpha: 0.4),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    project.name,
                    style: TextStyle(
                      color: AppTheme.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${project.currentBranch}   ·   ${project.statusSummary}',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _buildBadge(),
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppTheme.textMuted, size: 18),
              color: AppTheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'delete',
                  onTap: onDelete,
                  child: const Row(
                    children: [
                      Icon(Icons.delete_outline, color: AppTheme.danger, size: 18),
                      SizedBox(width: 8),
                      Text('Remover', style: TextStyle(color: AppTheme.danger)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
