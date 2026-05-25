import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../models/git_project.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../utils/responsive.dart';
import '../widgets/modern_card.dart';
import '../widgets/status_badge.dart';
import '../widgets/glass_container.dart';
import '../widgets/modern_button.dart';
import '../widgets/modern_dialog.dart';
import '../widgets/language_selector.dart';
import 'project_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  final Locale locale;
  final ValueChanged<Locale> onLocaleChange;

  const DashboardScreen({
    super.key,
    required this.locale,
    required this.onLocaleChange,
  });

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

  double _sidebarWidth = 300;
  static const double _minSidebarWidth = 200;
  static const double _maxSidebarWidth = 500;
  bool _isDragging = false;

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
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          l10n.addRepo,
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
                decoration: InputDecoration(
                  labelText: l10n.projectName,
                  prefixIcon: const Icon(Icons.folder_outlined),
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
                        labelText: l10n.projectPath,
                        prefixIcon: const Icon(Icons.folder_open_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ModernButton(
                    icon: Icons.folder_copy_outlined,
                    label: l10n.browse,
                    variant: ModernButtonVariant.ghost,
                    compact: true,
                    onPressed: () async {
                      final dir = await getDirectoryPath();
                      if (dir != null) pathCtrl.text = dir;
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          ModernButton(
            label: l10n.cancel,
            variant: ModernButtonVariant.ghost,
            compact: true,
            onPressed: () => Navigator.pop(ctx),
          ),
          ModernButton(
            label: l10n.add,
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
          ),
        ],
      ),
    );
  }

  void _confirmDelete(GitProject project) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => ModernConfirmDialog(
        title: l10n.deleteRepoTitle,
        message: l10n.deleteRepoMessage(project.name),
        icon: Icons.folder_delete_outlined,
        confirmLabel: l10n.remove,
        cancelLabel: l10n.cancel,
        confirmVariant: ModernButtonVariant.danger,
        onConfirm: () async {
          await _api.deleteProject(project.path);
          if (_selectedProject?.path == project.path) {
            setState(() => _selectedProject = null);
          }
          await _loadProjects();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final available = _projects.where((p) => p.isAvailable).length;
    final unavailable = _projects.length - available;
    final withChanges = _projects.where((p) {
      if (!p.isAvailable) return false;
      final hasLocalChanges = p.statusSummary != 'Limpo';
      final outOfSync = p.ahead > 0 || p.behind > 0;
      return hasLocalChanges || outOfSync;
    }).length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isCompact = width < 600;

        Widget sidebarContent = _buildSidebarContent(
          l10n: l10n,
          available: available,
          unavailable: unavailable,
          withChanges: withChanges,
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

        if (isCompact) {
          return Scaffold(
            backgroundColor: AppTheme.bg,
            appBar: AppBar(
              backgroundColor: AppTheme.bgElevated,
              elevation: 0,
              title: Text(l10n.appTitle),
              actions: [
                LanguageSelector(
                  currentLocale: widget.locale,
                  onChanged: widget.onLocaleChange,
                ),
                const SizedBox(width: 8),
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
        }

        return Scaffold(
          backgroundColor: AppTheme.bg,
          body: Row(
            children: [
              SizedBox(
                width: _sidebarWidth,
                child: sidebarContent,
              ),
              MouseRegion(
                cursor: SystemMouseCursors.resizeLeftRight,
                child: Listener(
                  onPointerDown: (_) => setState(() => _isDragging = true),
                  onPointerUp: (_) => setState(() => _isDragging = false),
                  onPointerCancel: (_) => setState(() => _isDragging = false),
                  onPointerMove: (event) {
                    if (event.buttons == 1) {
                      setState(() {
                        _sidebarWidth += event.delta.dx;
                        _sidebarWidth = _sidebarWidth.clamp(_minSidebarWidth, _maxSidebarWidth);
                      });
                    }
                  },
                  child: Container(
                    width: 10,
                    color: _isDragging
                        ? AppTheme.accent.withValues(alpha: 0.25)
                        : Colors.transparent,
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 3,
                        height: _isDragging ? 60 : 36,
                        decoration: BoxDecoration(
                          color: _isDragging
                              ? AppTheme.accent
                              : AppTheme.borderStrong.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(child: body),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSidebarContent({
    required AppLocalizations l10n,
    required int available,
    required int unavailable,
    required int withChanges,
    required bool compact,
  }) {
    final s = Responsive.sidebarScale(_sidebarWidth);

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
              padding: EdgeInsets.all(Responsive.pad(16, s)),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(Responsive.pad(8, s)),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.accent.withValues(alpha: 0.3),
                              AppTheme.accentHover.withValues(alpha: 0.15),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.folder_copy_outlined,
                          color: AppTheme.accent,
                          size: Responsive.icon(22, s),
                        ),
                      ),
                      SizedBox(width: Responsive.pad(10, s)),
                      Expanded(
                        child: Text(
                          l10n.appTitle,
                          style: TextStyle(
                            color: AppTheme.text,
                            fontSize: Responsive.font(20, s),
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      LanguageSelector(
                        currentLocale: widget.locale,
                        onChanged: widget.onLocaleChange,
                      ),
                      SizedBox(width: Responsive.pad(6, s)),
                      IconButton(
                        icon: Icon(
                          Icons.refresh,
                          color: AppTheme.textMuted,
                          size: Responsive.icon(18, s),
                        ),
                        onPressed: _loadProjects,
                        tooltip: l10n.refresh,
                      ),
                    ],
                  ),
                  SizedBox(height: Responsive.pad(12, s)),
                  TextField(
                    onChanged: (v) {
                      setState(() {
                        _search = v;
                        _applyFilter();
                      });
                    },
                    style: TextStyle(
                      color: AppTheme.text,
                      fontSize: Responsive.font(13, s),
                    ),
                    decoration: InputDecoration(
                      hintText: l10n.searchRepo,
                      prefixIcon: Icon(
                        Icons.search,
                        color: AppTheme.textMuted,
                        size: Responsive.icon(18, s),
                      ),
                      suffixIcon: _search.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: AppTheme.textMuted,
                                size: Responsive.icon(16, s),
                              ),
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
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.pad(14, s),
                vertical: Responsive.pad(10, s),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statItem(_projects.length.toString(), l10n.total, AppTheme.text, s),
                  _statItem(available.toString(), l10n.ok, AppTheme.success, s),
                  _statItem(withChanges.toString(), l10n.withChanges, withChanges > 0 ? AppTheme.warning : AppTheme.textMuted, s),
                  _statItem(unavailable.toString(), l10n.unavailable, unavailable > 0 ? AppTheme.danger : AppTheme.textMuted, s),
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
                          padding: EdgeInsets.all(Responsive.pad(10, s)),
                          itemCount: _filtered.length,
                          itemBuilder: (context, index) {
                            final project = _filtered[index];
                            final isSelected = _selectedProject?.path == project.path;
                            return _ProjectCard(
                              project: project,
                              isSelected: isSelected,
                              sidebarWidth: _sidebarWidth,
                              scale: s,
                              onTap: () => setState(() => _selectedProject = project),
                              onDelete: () => _confirmDelete(project),
                            );
                          },
                        ),
                      ),
          ),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(Responsive.pad(12, s)),
            decoration: BoxDecoration(
              color: AppTheme.bgElevated,
              border: Border(top: BorderSide(color: AppTheme.borderStrong.withValues(alpha: 0.3))),
            ),
            child: ModernButton(
              icon: Icons.add_rounded,
              label: l10n.addRepo,
              onPressed: _showAddDialog,
              compact: true,
              scale: s,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label, Color color, double scale) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: Responsive.font(16, scale),
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: Responsive.pad(2, scale)),
        Text(
          label,
          style: TextStyle(
            color: AppTheme.textMuted,
            fontSize: Responsive.font(9, scale),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
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
          Icon(Icons.inbox_outlined, size: 44, color: AppTheme.textMuted.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context)!.noRepo,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            AppLocalizations.of(context)!.noRepoHint,
            style: TextStyle(color: AppTheme.textMuted.withValues(alpha: 0.6), fontSize: 11),
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
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surface.withValues(alpha: 0.4),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.account_tree_outlined,
              size: 56,
              color: AppTheme.textMuted.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            AppLocalizations.of(context)!.selectRepo,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppLocalizations.of(context)!.selectRepoHint,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textMuted.withValues(alpha: 0.6),
              fontSize: 12,
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
  final double sidebarWidth;
  final double scale;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ProjectCard({
    required this.project,
    required this.isSelected,
    required this.sidebarWidth,
    required this.scale,
    required this.onTap,
    required this.onDelete,
  });

  StatusBadge _buildBadge() {
    if (!project.isAvailable) return StatusBadge.error(tooltip: 'Unavailable');
    if (!project.existsOnDisk) return StatusBadge.error(tooltip: 'Not found');
    if (!project.hasGit) return StatusBadge.warn(tooltip: 'No git');
    final bool hasLocalChanges = project.statusSummary != 'Limpo';
    final bool outOfSync = project.ahead > 0 || project.behind > 0;
    if (hasLocalChanges || outOfSync) return StatusBadge.warn(tooltip: 'Has changes');
    return StatusBadge.ok();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: Responsive.pad(8, scale)),
      child: ModernCard(
        onTap: onTap,
        color: isSelected ? AppTheme.surfaceActive : null,
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.pad(12, scale),
          vertical: Responsive.pad(10, scale),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildBadge(),
            SizedBox(width: Responsive.pad(10, scale)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tooltip(
                    message: project.name,
                    waitDuration: const Duration(milliseconds: 400),
                    child: Text(
                      project.name,
                      style: TextStyle(
                        color: AppTheme.text,
                        fontSize: Responsive.font(13, scale),
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  SizedBox(height: Responsive.pad(2, scale)),
                  Text(
                    project.currentBranch,
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: Responsive.font(11, scale),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                color: AppTheme.textMuted,
                size: Responsive.icon(16, scale),
              ),
              color: AppTheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'delete',
                  onTap: onDelete,
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: AppTheme.danger, size: Responsive.icon(16, scale)),
                      SizedBox(width: Responsive.pad(8, scale)),
                      Text(AppLocalizations.of(context)!.remove, style: const TextStyle(color: AppTheme.danger, fontSize: 13)),
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
