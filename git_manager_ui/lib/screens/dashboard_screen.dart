import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
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
      _showError('${AppLocalizations.of(context)!.errorLoadingProjects}: $e');
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
        title: Text(
          AppLocalizations.of(context)!.addRepo,
          style: const TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold),
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
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.projectPath,
                        prefixIcon: const Icon(Icons.folder_open_outlined),
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
                    label: Text(AppLocalizations.of(context)!.browse),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context)!.cancel),
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
            child: Text(AppLocalizations.of(context)!.add),
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
        title: Text(
          AppLocalizations.of(context)!.removeRepo,
          style: const TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Remover "${project.name}" da lista?\n\n${AppLocalizations.of(context)!.removeRepoConfirm}',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context)!.cancel),
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
            child: Text(AppLocalizations.of(context)!.remove),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final available = _projects.where((p) => p.isAvailable).length;
    final withChanges = _projects.where((p) => p.isAvailable && p.statusSummary != l10n.ok).length;
    final unavailable = _projects.length - available;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isCompact = width < 600;
        final isMedium = width >= 600 && width < 1100;
        final isWide = width >= 1100;

        Widget sidebarContent = _buildSidebarContent(
          l10n: l10n,
          available: available,
          withChanges: withChanges,
          unavailable: unavailable,
          compact: isCompact,
        );

        Widget body = Container(
          color: AppTheme.bg,
          child: _selectedProject == null
              ? const _WelcomeArea()
              : ProjectDetailScreen(
                  project: _selectedProject!,
                  api: _api,
                  inline: true,
                ),
        );

        if (isWide) {
          return Scaffold(
            backgroundColor: AppTheme.bg,
            body: Row(
              children: [
                SizedBox(width: 340, child: sidebarContent),
                Expanded(child: body),
              ],
            ),
          );
        }

        if (isMedium) {
          return Scaffold(
            backgroundColor: AppTheme.bg,
            body: Row(
              children: [
                NavigationRail(
                  backgroundColor: AppTheme.bgElevated,
                  selectedIndex: 0,
                  labelType: NavigationRailLabelType.selected,
                  destinations: [
                    NavigationRailDestination(
                      icon: const Icon(Icons.folder_copy_outlined, color: AppTheme.textMuted),
                      selectedIcon: const Icon(Icons.folder_copy_outlined, color: AppTheme.accent),
                      label: Text(l10n.appTitle, style: const TextStyle(fontSize: 10)),
                    ),
                  ],
                  trailing: IconButton(
                    icon: const Icon(Icons.add, color: AppTheme.text),
                    onPressed: _showAddDialog,
                    tooltip: l10n.addRepo,
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      SizedBox(width: 280, child: sidebarContent),
                      Expanded(child: body),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        // Compact: drawer + body
        return Scaffold(
          backgroundColor: AppTheme.bg,
          appBar: AppBar(
            backgroundColor: AppTheme.bgElevated,
            elevation: 0,
            title: Text(l10n.appTitle),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: AppTheme.textMuted),
                onPressed: _loadProjects,
                tooltip: l10n.refresh,
              ),
            ],
          ),
          drawer: Drawer(
            backgroundColor: AppTheme.bgElevated,
            child: sidebarContent,
          ),
          body: body,
        );
      },
    );
  }

  Widget _buildSidebarContent({
    required AppLocalizations l10n,
    required int available,
    required int withChanges,
    required int unavailable,
    required bool compact,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgElevated,
        border: compact
            ? null
            : Border(right: BorderSide(color: AppTheme.borderStrong.withValues(alpha: 0.3))),
      ),
      child: Column(
        children: [
          if (!compact)
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
                        child: const Icon(Icons.folder_copy_outlined, color: AppTheme.accent, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.appTitle,
                          style: const TextStyle(
                            color: AppTheme.text, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: AppTheme.textMuted, size: 20),
                        onPressed: _loadProjects,
                        tooltip: l10n.refresh,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    onChanged: (v) {
                      setState(() {
                        _search = v;
                        _applyFilter();
                      });
                    },
                    style: const TextStyle(color: AppTheme.text),
                    decoration: InputDecoration(
                      hintText: l10n.searchRepo,
                      prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted),
                      suffixIcon: _search.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: AppTheme.textMuted, size: 18),
                              onPressed: () => setState(() { _search = ''; _applyFilter(); }),
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          if (!compact)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statItem(_projects.length.toString(), l10n.total, AppTheme.text),
                  _statItem(available.toString(), l10n.ok, AppTheme.success),
                  _statItem(withChanges.toString(), l10n.alt, AppTheme.warning),
                  _statItem(
                    unavailable.toString(),
                    l10n.unavailable,
                    unavailable > 0 ? AppTheme.danger : AppTheme.textMuted,
                  ),
                ],
              ),
            ),
          if (!compact) const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.bgElevated,
              border: Border(top: BorderSide(color: AppTheme.borderStrong.withValues(alpha: 0.3))),
            ),
            child: _AddRepoButton(onTap: _showAddDialog),
          ),
        ],
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
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderStrong.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.bg.withValues(alpha: 0.5),
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
              Text(
                AppLocalizations.of(context)!.addRepo,
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
          Text(
            AppLocalizations.of(context)!.noRepo,
            style: TextStyle(color: AppTheme.textMuted, fontSize: 15, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            AppLocalizations.of(context)!.noRepoHint,
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
          Text(
            AppLocalizations.of(context)!.selectRepo,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.selectRepoHint,
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

  StatusBadge _buildBadge(BuildContext context) {
    if (!project.isAvailable) return StatusBadge.error(AppLocalizations.of(context)!.unavailable);
    if (project.statusSummary == AppLocalizations.of(context)!.ok) return StatusBadge.ok();
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
            _buildBadge(context),
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
