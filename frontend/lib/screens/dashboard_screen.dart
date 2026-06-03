import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:git_manager_ui/generated/l10n/app_localizations.dart';
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
import '../widgets/ssh_setup_dialog.dart';
import '../services/notification_service.dart';
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
  final Set<String> _expandedGroups = {};

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
      NotificationService().showError(
        AppLocalizations.of(context)!.notificationError,
        detail: '${AppLocalizations.of(context)!.errorLoadingProjects}: $e',
      );
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

  String _pathBasename(String path) {
    final parts = path.replaceAll('\\', '/').split('/').where((s) => s.isNotEmpty).toList();
    return parts.isNotEmpty ? parts.last : path;
  }

  void _showAddDialog() {
    final groupCtrl = TextEditingController();
    final groupFocus = FocusNode();
    final l10n = AppLocalizations.of(context)!;
    final groupOptions = _projects.map((p) => p.group).where((g) => g.isNotEmpty).toSet().toList()..sort();
    List<String> selectedPaths = [];
    bool groupFocused = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) {
          final query = groupCtrl.text.trim().toLowerCase();
          final filtered = query.isEmpty
              ? groupOptions
              : groupOptions.where((g) => g.toLowerCase().contains(query)).toList();
          final showDropdown = groupFocused || (query.isNotEmpty && filtered.isNotEmpty);

          return AlertDialog(
            backgroundColor: AppTheme.bgElevated,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              l10n.addRepo,
              style: const TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold),
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 380, maxWidth: 560, maxHeight: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Group field with expandable dropdown
                  Focus(
                    onFocusChange: (hasFocus) {
                      setStateDialog(() => groupFocused = hasFocus);
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: groupCtrl,
                          focusNode: groupFocus,
                          style: const TextStyle(color: AppTheme.text),
                          decoration: InputDecoration(
                            labelText: l10n.groupName,
                            prefixIcon: const Icon(Icons.group_outlined),
                            suffixIcon: groupCtrl.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, color: AppTheme.textMuted, size: 18),
                                    onPressed: () {
                                      groupCtrl.clear();
                                      setStateDialog(() {});
                                    },
                                  )
                                : null,
                          ),
                          onChanged: (_) => setStateDialog(() {}),
                        ),
                        if (showDropdown)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            constraints: const BoxConstraints(maxHeight: 160),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.borderStrong.withValues(alpha: 0.3)),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Scrollbar(
                                child: filtered.isNotEmpty
                                    ? ListView.builder(
                                        shrinkWrap: true,
                                        padding: EdgeInsets.zero,
                                        itemCount: filtered.length,
                                        itemBuilder: (context, index) {
                                          final option = filtered[index];
                                          return ListTile(
                                            dense: true,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                                            title: Text(
                                              option,
                                              style: const TextStyle(color: AppTheme.text, fontSize: 13),
                                            ),
                                            onTap: () {
                                              groupCtrl.text = option;
                                              groupFocus.unfocus();
                                              setStateDialog(() => groupFocused = false);
                                            },
                                          );
                                        },
                                      )
                                    : Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Text(
                                          query.isEmpty ? l10n.empty : l10n.noRepos,
                                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                                        ),
                                      ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ModernButton(
                    icon: Icons.folder_copy_outlined,
                    label: l10n.browse,
                    variant: ModernButtonVariant.ghost,
                    compact: true,
                    onPressed: () async {
                      final dirs = await getDirectoryPaths();
                      if (dirs.isNotEmpty) {
                        setStateDialog(() {
                          for (final d in dirs.whereType<String>()) {
                            if (!selectedPaths.contains(d)) {
                              selectedPaths.add(d);
                            }
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  if (selectedPaths.isNotEmpty)
                    Flexible(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.surface.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.borderStrong.withValues(alpha: 0.25)),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: selectedPaths.length,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemBuilder: (context, index) {
                            final path = selectedPaths[index];
                            final name = _pathBasename(path);
                            return ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                              title: Text(
                                name,
                                style: const TextStyle(color: AppTheme.text, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                path,
                                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.close, color: AppTheme.danger, size: 18),
                                onPressed: () {
                                  setStateDialog(() {
                                    selectedPaths.removeAt(index);
                                  });
                                },
                                tooltip: l10n.remove,
                              ),
                            );
                          },
                        ),
                      ),
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
                label: selectedPaths.isEmpty ? l10n.add : '${l10n.add} (${selectedPaths.length})',
                onPressed: selectedPaths.isEmpty
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        final group = groupCtrl.text.trim();
                        final futures = selectedPaths.map((path) async {
                          final name = _pathBasename(path);
                          try {
                            await _api.addProject(name, path, group: group);
                          } catch (e) {
                            NotificationService().showError(
                              l10n.notificationError,
                              detail: '$name — $e',
                            );
                          }
                        });
                        await Future.wait(futures);
                        await _loadProjects();
                        NotificationService().showSuccess(l10n.repoAddedSuccess);
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditNameDialog(GitProject project) {
    final ctrl = TextEditingController(text: project.name);
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l10n.repoName, style: const TextStyle(color: AppTheme.text, fontWeight: FontWeight.bold)),
        content: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 320),
          child: TextField(
            controller: ctrl,
            style: const TextStyle(color: AppTheme.text),
            decoration: InputDecoration(
              labelText: l10n.projectName,
              prefixIcon: const Icon(Icons.edit_outlined),
            ),
            autofocus: true,
            onSubmitted: (v) {
              Navigator.pop(ctx);
              _doRename(project, v.trim());
            },
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
            label: l10n.confirm,
            onPressed: () {
              Navigator.pop(ctx);
              _doRename(project, ctrl.text.trim());
            },
          ),
        ],
      ),
    );
  }

  Future<void> _doRename(GitProject project, String newName) async {
    if (newName.isEmpty || newName == project.name) return;
    try {
      final updatedProject = GitProject(
        name: newName,
        path: project.path,
        notes: project.notes,
        group: project.group,
        existsOnDisk: project.existsOnDisk,
        hasGit: project.hasGit,
        currentBranch: project.currentBranch,
        statusSummary: project.statusSummary,
        ahead: project.ahead,
        behind: project.behind,
      );
      await _api.updateProject(updatedProject);
      if (_selectedProject?.path == project.path) {
        setState(() => _selectedProject = updatedProject);
      }
      await _loadProjects();
    } catch (e) {
      NotificationService().showError(
        AppLocalizations.of(context)!.notificationError,
        detail: '${AppLocalizations.of(context)!.error}: $e',
      );
    }
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
                  onProjectChanged: (updated) {
                    setState(() => _selectedProject = updated);
                    _loadProjects();
                  },
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
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: AppTheme.textMuted),
                  color: AppTheme.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  onSelected: (value) {
                    switch (value) {
                      case 'refresh':
                        _loadProjects();
                        break;
                      case 'ssh':
                        SshSetupDialog.show(context, _api);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(value: 'refresh', child: Text(l10n.refresh)),
                    PopupMenuItem(value: 'ssh', child: Text('Configurar chave SSH')),
                  ],
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
                  LayoutBuilder(builder: (context, headerConstraints) {
                    final isNarrow = headerConstraints.maxWidth < 330;
                    final actionMenu = PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: AppTheme.textMuted, size: Responsive.icon(18, s)),
                      color: AppTheme.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      onSelected: (value) {
                        switch (value) {
                          case 'ssh':
                            SshSetupDialog.show(context, _api);
                            break;
                          case 'refresh':
                            _loadProjects();
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(value: 'refresh', child: Text(l10n.refresh)),
                        PopupMenuItem(value: 'ssh', child: Text('Configurar chave SSH')),
                      ],
                    );

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
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
                            if (!isNarrow) ...[
                              const SizedBox(width: 6),
                              LanguageSelector(
                                currentLocale: widget.locale,
                                onChanged: widget.onLocaleChange,
                              ),
                              SizedBox(width: Responsive.pad(6, s)),
                              actionMenu,
                            ],
                          ],
                        ),
                        if (isNarrow) ...[
                          SizedBox(height: Responsive.pad(10, s)),
                          Row(
                            children: [
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 160),
                                child: LanguageSelector(
                                  currentLocale: widget.locale,
                                  onChanged: widget.onLocaleChange,
                                ),
                              ),
                              SizedBox(width: Responsive.pad(6, s)),
                              actionMenu,
                            ],
                          ),
                        ],
                      ],
                    );
                  }),
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
                    ? _EmptyState(onAdd: _showAddDialog)
                    : LayoutBuilder(builder: (context, listConstraints) {
                        final grouped = <String, List<GitProject>>{};
                        for (final project in _filtered) {
                          final key = project.group.trim();
                          grouped.putIfAbsent(key, () => []).add(project);
                        }
                        final groupKeys = grouped.keys.toList()
                          ..sort((a, b) {
                            if (a.isEmpty && b.isNotEmpty) return 1;
                            if (a.isNotEmpty && b.isEmpty) return -1;
                            return a.compareTo(b);
                          });

                        return Scrollbar(
                          child: ListView(
                            padding: EdgeInsets.all(Responsive.pad(10, s)),
                            children: groupKeys.map((groupKey) {
                              final projects = grouped[groupKey]!;
                              final displayName = groupKey.isEmpty ? l10n.ungrouped : groupKey;
                              final expanded = _expandedGroups.isEmpty || _expandedGroups.contains(groupKey);

                              return Theme(
                                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                child: ExpansionTile(
                                  key: PageStorageKey(groupKey),
                                  initiallyExpanded: expanded,
                                  onExpansionChanged: (opened) {
                                    setState(() {
                                      if (opened) {
                                        _expandedGroups.add(groupKey);
                                      } else {
                                        _expandedGroups.remove(groupKey);
                                      }
                                    });
                                  },
                                  tilePadding: EdgeInsets.symmetric(horizontal: Responsive.pad(8, s)),
                                  collapsedIconColor: AppTheme.textMuted,
                                  iconColor: AppTheme.accent,
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          displayName,
                                          style: TextStyle(
                                            color: AppTheme.text,
                                            fontSize: Responsive.font(13, s),
                                            fontWeight: FontWeight.w700,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: Responsive.pad(8, s),
                                          vertical: Responsive.pad(4, s),
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.surface.withValues(alpha: 0.7),
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          '${projects.length}',
                                          style: TextStyle(
                                            color: AppTheme.textMuted,
                                            fontSize: Responsive.font(11, s),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  children: projects.map((project) {
                                    final isSelected = _selectedProject?.path == project.path;
                                    return _ProjectCard(
                                      project: project,
                                      isSelected: isSelected,
                                      sidebarWidth: _sidebarWidth,
                                      scale: s,
                                      onTap: () => setState(() => _selectedProject = project),
                                      onDelete: () => _confirmDelete(project),
                                      onRename: () => _showEditNameDialog(project),
                                    );
                                  }).toList(),
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      }),
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
  final VoidCallback onAdd;

  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 44, color: AppTheme.textMuted.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(
            l10n.noRepo,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.noRepoHint,
            style: TextStyle(color: AppTheme.textMuted.withValues(alpha: 0.6), fontSize: 11),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ModernButton(
            icon: Icons.add_rounded,
            label: l10n.addRepo,
            onPressed: onAdd,
            compact: true,
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
  final VoidCallback onRename;

  const _ProjectCard({
    required this.project,
    required this.isSelected,
    required this.sidebarWidth,
    required this.scale,
    required this.onTap,
    required this.onDelete,
    required this.onRename,
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

  String _shortenPath(String raw) {
    final parts = raw.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.length <= 2) {
      return raw.startsWith('/') ? '/${parts.join('/')}' : parts.join('/');
    }
    return '../${parts.sublist(parts.length - 2).join('/')}';
  }

  @override
  Widget build(BuildContext context) {
    final bool outOfSync = project.ahead > 0 || project.behind > 0;
    final String branch = project.currentBranch.isEmpty ? '—' : project.currentBranch;
    final String status = project.statusSummary;
    final bool hasStatus = status.isNotEmpty && status != 'Limpo';

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
                  // Nome do projeto + chips de sync
                  Row(
                    children: [
                      Expanded(
                        child: Tooltip(
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
                      ),
                      if (outOfSync) ...[
                        SizedBox(width: Responsive.pad(6, scale)),
                        _SyncChip(ahead: project.ahead, behind: project.behind, scale: scale),
                      ],
                    ],
                  ),
                  SizedBox(height: Responsive.pad(4, scale)),
                  // Branch + status
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.account_tree_outlined,
                        size: Responsive.icon(12, scale),
                        color: AppTheme.accent,
                      ),
                      SizedBox(width: Responsive.pad(4, scale)),
                      Flexible(
                        child: Text(
                          branch,
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: Responsive.font(11, scale),
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (hasStatus) ...[
                        SizedBox(width: Responsive.pad(6, scale)),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                            color: AppTheme.textMuted,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        SizedBox(width: Responsive.pad(6, scale)),
                        Flexible(
                          child: Text(
                            status,
                            style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: Responsive.font(10, scale),
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ],
                  ),
                  // Path estilizado
                  if (project.path.isNotEmpty) ...[
                    SizedBox(height: Responsive.pad(6, scale)),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: Responsive.pad(8, scale),
                        vertical: Responsive.pad(4, scale),
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surface.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppTheme.borderStrong.withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.folder_open_outlined,
                            size: Responsive.icon(11, scale),
                            color: AppTheme.textMuted,
                          ),
                          SizedBox(width: Responsive.pad(4, scale)),
                          Flexible(
                            child: Text(
                              _shortenPath(project.path),
                              style: TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: Responsive.font(10, scale),
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0.2,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                  value: 'rename',
                  onTap: onRename,
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, color: AppTheme.accent, size: Responsive.icon(16, scale)),
                      SizedBox(width: Responsive.pad(8, scale)),
                      Text(AppLocalizations.of(context)!.repoName, style: const TextStyle(color: AppTheme.text, fontSize: 13)),
                    ],
                  ),
                ),
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

class _SyncChip extends StatelessWidget {
  final int ahead;
  final int behind;
  final double scale;

  const _SyncChip({required this.ahead, required this.behind, required this.scale});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: Responsive.pad(6, scale), vertical: Responsive.pad(2, scale)),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (ahead > 0) ...[
            Icon(Icons.arrow_upward, size: Responsive.icon(10, scale), color: AppTheme.warning),
            SizedBox(width: Responsive.pad(2, scale)),
            Text(
              '$ahead',
              style: TextStyle(
                color: AppTheme.warning,
                fontSize: Responsive.font(10, scale),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          if (ahead > 0 && behind > 0) SizedBox(width: Responsive.pad(4, scale)),
          if (behind > 0) ...[
            Icon(Icons.arrow_downward, size: Responsive.icon(10, scale), color: AppTheme.warning),
            SizedBox(width: Responsive.pad(2, scale)),
            Text(
              '$behind',
              style: TextStyle(
                color: AppTheme.warning,
                fontSize: Responsive.font(10, scale),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
