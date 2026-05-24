import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../models/git_commit.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../utils/responsive.dart';
import '../widgets/modern_button.dart';
import '../widgets/modern_card.dart';

/// Tela de timeline com vista compacta (lista) e vista gráfica (grafo).
class TimelineScreen extends StatefulWidget {
  final String path;
  final ApiService api;

  const TimelineScreen({
    super.key,
    required this.path,
    required this.api,
  });

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen>
    with AutomaticKeepAliveClientMixin {
  List<GitCommit> _commits = [];
  List<GitCommit> _filtered = [];
  bool _loading = true;
  String? _error;
  String _query = '';
  bool _graphView = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final commits = await widget.api.getCommitGraph(widget.path);
      setState(() {
        _commits = commits;
        _filtered = commits;
        _loading = false;
        _error = null;
      });
    } catch (e, st) {
      setState(() {
        _loading = false;
        _error = '$e\n$st';
      });
    }
  }

  void _applyFilter() {
    final q = _query.toLowerCase();
    if (q.isEmpty) {
      _filtered = _commits;
    } else {
      _filtered = _commits.where((c) {
        return c.message.toLowerCase().contains(q) ||
            c.shortId.toLowerCase().contains(q) ||
            c.authorName.toLowerCase().contains(q);
      }).toList();
    }
  }

  void _onSearch(String value) {
    setState(() {
      _query = value;
      _applyFilter();
    });
  }

  void _copyHash(String hash) {
    Clipboard.setData(ClipboardData(text: hash));
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.copied),
        duration: const Duration(seconds: 2),
        backgroundColor: AppTheme.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _cherryPick(String commitId) async {
    try {
      final result = await widget.api.cherryPick(widget.path, commitId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result),
            duration: const Duration(seconds: 3),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context)!.error}: $e'),
            duration: const Duration(seconds: 3),
            backgroundColor: AppTheme.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  void _showDiffDialog(GitCommit commit) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('${l10n.commitDetails} — ${commit.shortId}',
            style: const TextStyle(color: AppTheme.text, fontSize: 15)),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(commit.message,
                    style: const TextStyle(
                        color: AppTheme.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                _MetaRow(label: l10n.commitAuthor, value: commit.authorName),
                _MetaRow(label: l10n.commitDate, value: _fmtDate(commit.commitTime)),
                if (commit.branchNames.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: commit.branchNames
                        .map((b) => _BranchChip(name: b))
                        .toList(),
                  ),
                ],
                if (commit.parentIds.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('${l10n.parentCommits}:',
                      style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  ...commit.parentIds.map((p) => Text(p,
                      style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                          fontFamily: 'monospace'))),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.close,
                style: const TextStyle(color: AppTheme.accent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context)!;

    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.accent));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.danger),
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            const SizedBox(height: 12),
            _RetryButton(onPressed: _loadData),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final s = Responsive.bodyScale(constraints.maxWidth);
        return Padding(
          padding: EdgeInsets.all(Responsive.pad(12, s)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Toolbar ──
              Row(
                children: [
                  Expanded(
                    child: ModernCard(
                      padding: EdgeInsets.symmetric(
                        horizontal: Responsive.pad(10, s),
                        vertical: Responsive.pad(6, s),
                      ),
                      borderRadius: BorderRadius.circular(10),
                      child: Row(
                        children: [
                          Icon(Icons.search,
                              size: Responsive.icon(16, s),
                              color: AppTheme.textMuted),
                          SizedBox(width: Responsive.pad(8, s)),
                          Expanded(
                            child: TextField(
                              onChanged: _onSearch,
                              style: TextStyle(
                                color: AppTheme.text,
                                fontSize: Responsive.font(13, s),
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: l10n.searchCommits,
                                hintStyle: TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: Responsive.font(13, s),
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: Responsive.pad(10, s)),
                  ModernButton(
                    label: _graphView
                        ? l10n.graphCompactView
                        : l10n.graphDetailedView,
                    icon: _graphView
                        ? Icons.view_list_outlined
                        : Icons.account_tree_outlined,
                    variant: ModernButtonVariant.ghost,
                    compact: true,
                    onPressed: () => setState(() => _graphView = !_graphView),
                  ),
                ],
              ),
              SizedBox(height: Responsive.pad(10, s)),
              // ── Content ──
              Expanded(
                child: _filtered.isEmpty
                    ? Center(
                        child: Text(
                          l10n.noCommitsToShow,
                          style: const TextStyle(color: AppTheme.textMuted),
                        ),
                      )
                    : _graphView
                        ? _GraphView(
                            commits: _filtered,
                            onRefresh: _loadData,
                          )
                        : _CompactListView(
                            commits: _filtered,
                            onCopyHash: _copyHash,
                            onViewDiff: _showDiffDialog,
                            onCherryPick: _cherryPick,
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ------------------------------------------------------------------
// Helpers
// ------------------------------------------------------------------
String _fmtDate(DateTime dt) {
  return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}'
      ' ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

// ------------------------------------------------------------------
// Graph layout — lanes & colors shared between list and painter
// ------------------------------------------------------------------
class _GraphLayout {
  final List<GitCommit> commits;
  final Map<String, int> commitLanes = {};
  final Map<String, Color> laneColor = {};
  final Map<String, Color> branchColor = {};
  late final int maxLane;

  _GraphLayout(this.commits) {
    _assignLanesAndColors();
    maxLane = commitLanes.isEmpty
        ? 0
        : commitLanes.values.reduce(math.max);
  }

  void _assignLanesAndColors() {
    final branchLane = <String, int>{};
    int nextLane = 0;
    final seenBranches = <String>{};

    for (final c in commits) {
      for (final b in c.branchNames) {
        seenBranches.add(_bareName(b));
      }
    }

    final ordered = seenBranches.toList()
      ..sort((a, b) => _branchPriority(a).compareTo(_branchPriority(b)));
    for (final b in ordered) {
      branchLane[b.toLowerCase()] = nextLane++;
    }

    for (int i = commits.length - 1; i >= 0; i--) {
      final c = commits[i];
      int lane = -1;
      for (final b in c.branchNames) {
        final l = branchLane[_bareName(b).toLowerCase()];
        if (l != null) {
          lane = lane == -1 || l < lane ? l : lane;
        }
      }
      if (lane == -1) {
        for (final pid in c.parentIds) {
          final pl = commitLanes[pid];
          if (pl != null) {
            lane = pl;
            break;
          }
        }
      }
      if (lane == -1) lane = 0;
      commitLanes[c.id] = lane;
    }

    final maxL = commitLanes.isEmpty
        ? 0
        : commitLanes.values.reduce(math.max);

    const lanePalette = [
      Color(0xFFF97316), // laranja
      Color(0xFF22C55E), // verde
      Color(0xFF3B82F6), // azul
      Color(0xFFA855F7), // roxo
      Color(0xFFEF4444), // vermelho
      Color(0xFF14B8A6), // teal
      Color(0xFFF59E0B), // amarelo
      Color(0xFFEC4899), // rosa
      Color(0xFF6366F1), // índigo
      Color(0xFF84CC16), // lime
      Color(0xFF06B6D4), // ciano
      Color(0xFFD946EF), // fuchsia
    ];

    for (int l = 0; l <= maxL; l++) {
      laneColor[_laneKey(l)] = lanePalette[l % lanePalette.length];
    }

    for (final b in ordered) {
      final c = _namedBranchColor(b) ??
          HSLColor.fromAHSL(
            1.0,
            (ordered.indexOf(b) * 47.0) % 360,
            0.78,
            0.72,
          ).toColor();
      branchColor[b.toLowerCase()] = c;
    }
  }

  static String _laneKey(int lane) => 'lane_$lane';

  static String _bareName(String b) => b.replaceAll(' (remoto)', '').trim();

  static int _branchPriority(String name) {
    final lower = name.toLowerCase();
    final p = ['main', 'master', 'develop', 'dev'];
    final i = p.indexOf(lower);
    return i >= 0 ? i : 999;
  }

  static Color? _namedBranchColor(String name) {
    final map = {
      'main': const Color(0xFFF97316),
      'master': const Color(0xFFF97316),
      'develop': const Color(0xFF22C55E),
      'dev': const Color(0xFF22C55E),
      'feature': const Color(0xFF3B82F6),
      'hotfix': const Color(0xFFEAB308),
      'release': const Color(0xFFA855F7),
    };
    return map[name.toLowerCase()];
  }

  Color colorForCommit(GitCommit c) {
    final lane = commitLanes[c.id] ?? 0;
    return laneColor[_laneKey(lane)] ?? AppTheme.accent;
  }

  Color colorForBranchName(String name) {
    return branchColor[_bareName(name).toLowerCase()] ??
        colorForCommit(
          commits.firstWhere(
            (c) => c.branchNames.contains(name),
            orElse: () => commits.first,
          ),
        );
  }
}

// ------------------------------------------------------------------
// Graph dimensions config
// ------------------------------------------------------------------
class _GraphDimensions {
  final double laneWidth;
  final double rowHeight;
  final double leftMargin;
  final double rightMargin;
  final double topMargin;
  final double bottomMargin;
  final double nodeRadius;
  final double hashFontSize;
  final double messageFontSize;
  final double metaFontSize;
  final double pillHeight;
  final double pillFontSize;
  final double pillMinWidth;
  final double pillHPad;
  final double connectionStroke;
  final double connectionAlpha;
  final double gridAlpha;

  const _GraphDimensions._({
    required this.laneWidth,
    required this.rowHeight,
    required this.leftMargin,
    required this.rightMargin,
    required this.topMargin,
    required this.bottomMargin,
    required this.nodeRadius,
    required this.hashFontSize,
    required this.messageFontSize,
    required this.metaFontSize,
    required this.pillHeight,
    required this.pillFontSize,
    required this.pillMinWidth,
    required this.pillHPad,
    required this.connectionStroke,
    required this.connectionAlpha,
    required this.gridAlpha,
  });

  static const compact = _GraphDimensions._(
    laneWidth: 40.0,
    rowHeight: 52.0,
    leftMargin: 100.0,
    rightMargin: 320.0,
    topMargin: 24.0,
    bottomMargin: 24.0,
    nodeRadius: 5.0,
    hashFontSize: 10.0,
    messageFontSize: 12.0,
    metaFontSize: 10.0,
    pillHeight: 14.0,
    pillFontSize: 9.0,
    pillMinWidth: 28.0,
    pillHPad: 8.0,
    connectionStroke: 1.8,
    connectionAlpha: 0.35,
    gridAlpha: 0.08,
  );

  static const comfortable = _GraphDimensions._(
    laneWidth: 52.0,
    rowHeight: 68.0,
    leftMargin: 120.0,
    rightMargin: 380.0,
    topMargin: 32.0,
    bottomMargin: 32.0,
    nodeRadius: 6.5,
    hashFontSize: 11.0,
    messageFontSize: 13.0,
    metaFontSize: 11.0,
    pillHeight: 18.0,
    pillFontSize: 10.0,
    pillMinWidth: 34.0,
    pillHPad: 10.0,
    connectionStroke: 2.2,
    connectionAlpha: 0.40,
    gridAlpha: 0.10,
  );
}

// ------------------------------------------------------------------
// Retry button
// ------------------------------------------------------------------
class _RetryButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _RetryButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final s = Responsive.scale(constraints.maxWidth, base: 400);
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onPressed,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.pad(20, s),
                vertical: Responsive.pad(10, s),
              ),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.borderStrong),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh,
                      size: Responsive.icon(16, s),
                      color: AppTheme.textSecondary),
                  SizedBox(width: Responsive.pad(8, s)),
                  Text(
                    AppLocalizations.of(context)!.retry,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: Responsive.font(13, s),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ------------------------------------------------------------------
// Compact list view
// ------------------------------------------------------------------
class _CompactListView extends StatelessWidget {
  final List<GitCommit> commits;
  final void Function(String hash) onCopyHash;
  final void Function(GitCommit commit) onViewDiff;
  final void Function(String commitId) onCherryPick;

  const _CompactListView({
    required this.commits,
    required this.onCopyHash,
    required this.onViewDiff,
    required this.onCherryPick,
  });

  @override
  Widget build(BuildContext context) {
    final layout = _GraphLayout(commits);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: commits.length,
      itemBuilder: (context, index) {
        final commit = commits[index];
        return _CompactCommitItem(
          commit: commit,
          color: layout.colorForCommit(commit),
          branchColors: {
            for (final b in commit.branchNames)
              b: layout.colorForBranchName(b),
          },
          onCopyHash: onCopyHash,
          onViewDiff: onViewDiff,
          onCherryPick: onCherryPick,
        );
      },
    );
  }
}

class _CompactCommitItem extends StatelessWidget {
  final GitCommit commit;
  final Color color;
  final Map<String, Color> branchColors;
  final void Function(String hash) onCopyHash;
  final void Function(GitCommit commit) onViewDiff;
  final void Function(String commitId) onCherryPick;

  const _CompactCommitItem({
    required this.commit,
    required this.color,
    required this.branchColors,
    required this.onCopyHash,
    required this.onViewDiff,
    required this.onCherryPick,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ModernCard(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        borderRadius: BorderRadius.circular(10),
        child: Row(
          children: [
            // Lane indicator
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Hash
            Text(
              commit.shortId,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 11,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 12),
            // Message + meta
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    commit.message.length > 70
                        ? '${commit.message.substring(0, 67)}...'
                        : commit.message,
                    style: const TextStyle(
                      color: AppTheme.text,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        commit.authorName,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 3,
                        height: 3,
                        decoration: const BoxDecoration(
                          color: AppTheme.textMuted,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _fmtDate(commit.commitTime),
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  if (commit.branchNames.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: commit.branchNames.map((b) {
                        final bc = branchColors[b] ?? color;
                        return _BranchChip(name: _GraphLayout._bareName(b), color: bc);
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Actions menu
            PopupMenuButton<String>(
              tooltip: l10n.moreActions,
              color: AppTheme.surface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              icon: const Icon(Icons.more_vert,
                  size: 18, color: AppTheme.textMuted),
              onSelected: (value) {
                switch (value) {
                  case 'copy':
                    onCopyHash(commit.id);
                    break;
                  case 'diff':
                    onViewDiff(commit);
                    break;
                  case 'cherry':
                    onCherryPick(commit.id);
                    break;
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'copy',
                  child: Row(
                    children: [
                      const Icon(Icons.copy, size: 16, color: AppTheme.accent),
                      const SizedBox(width: 8),
                      Text(l10n.copyHash,
                          style: const TextStyle(
                              color: AppTheme.text, fontSize: 12)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'diff',
                  child: Row(
                    children: [
                      const Icon(Icons.remove_red_eye,
                          size: 16, color: AppTheme.info),
                      const SizedBox(width: 8),
                      Text(l10n.viewDiff,
                          style: const TextStyle(
                              color: AppTheme.text, fontSize: 12)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'cherry',
                  child: Row(
                    children: [
                      const Icon(Icons.fork_right,
                          size: 16, color: AppTheme.warning),
                      const SizedBox(width: 8),
                      Text(l10n.cherryPick,
                          style: const TextStyle(
                              color: AppTheme.text, fontSize: 12)),
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

// ------------------------------------------------------------------
// Branch chip (compact)
// ------------------------------------------------------------------
class _BranchChip extends StatelessWidget {
  final String name;
  final Color? color;

  const _BranchChip({required this.name, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Text(
        name,
        style: TextStyle(
          color: c,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------
// Meta row (dialog)
// ------------------------------------------------------------------
class _MetaRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetaRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 12, height: 1.4),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------
// Graph view — with header controls and InteractiveViewer
// ------------------------------------------------------------------
class _GraphView extends StatefulWidget {
  final List<GitCommit> commits;
  final VoidCallback onRefresh;

  const _GraphView({
    required this.commits,
    required this.onRefresh,
  });

  @override
  State<_GraphView> createState() => _GraphViewState();
}

class _GraphViewState extends State<_GraphView> {
  bool _compact = true;
  final _transformationController = TransformationController();

  void _zoomIn() {
    final value = _transformationController.value.clone();
    value.scale(1.2);
    _transformationController.value = value;
  }

  void _zoomOut() {
    final value = _transformationController.value.clone();
    value.scale(1 / 1.2);
    _transformationController.value = value;
  }

  void _zoomReset() {
    _transformationController.value = Matrix4.identity();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dims = _compact ? _GraphDimensions.compact : _GraphDimensions.comfortable;
    final layout = _GraphLayout(widget.commits);
    final painter = _TimelinePainter(widget.commits, layout: layout, dims: dims);
    final size = painter.calculateSize();

    // Ensure minimum size so the painter always has room
    final displaySize = Size(
      math.max(size.width, 400),
      math.max(size.height, 200),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              const Icon(Icons.account_tree_outlined,
                  size: 14, color: AppTheme.accent),
              const SizedBox(width: 6),
              Text(
                l10n.graphicTimeline,
                style: const TextStyle(
                  color: AppTheme.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              // Zoom controls
              _IconButton(
                icon: Icons.zoom_in,
                tooltip: l10n.zoomIn,
                onPressed: _zoomIn,
              ),
              _IconButton(
                icon: Icons.zoom_out,
                tooltip: l10n.zoomOut,
                onPressed: _zoomOut,
              ),
              _IconButton(
                icon: Icons.center_focus_strong,
                tooltip: l10n.zoomReset,
                onPressed: _zoomReset,
              ),
              const SizedBox(width: 6),
              Container(
                height: 16,
                width: 1,
                color: AppTheme.border,
              ),
              const SizedBox(width: 6),
                // Compact / Comfortable toggle
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => setState(() => _compact = !_compact),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.borderStrong),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _compact ? Icons.view_comfy_alt : Icons.view_compact_alt,
                            size: 12,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _compact ? l10n.graphCompactView : l10n.graphDetailedView,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Refresh
                _IconButton(
                  icon: Icons.refresh,
                  tooltip: l10n.refresh,
                  onPressed: widget.onRefresh,
                ),
              ],
            ),
          ),
        const Divider(height: 1, color: AppTheme.border),
        // ── Interactive Viewer ──
        Expanded(
          child: InteractiveViewer(
            boundaryMargin: const EdgeInsets.all(80),
            minScale: 0.2,
            maxScale: 4.0,
            constrained: true,
            transformationController: _transformationController,
            child: Container(
              color: AppTheme.bg,
              alignment: Alignment.topLeft,
              constraints: BoxConstraints(
                minWidth: displaySize.width,
                minHeight: displaySize.height,
              ),
              child: SizedBox(
                width: displaySize.width,
                height: displaySize.height,
                child: CustomPaint(
                  size: displaySize,
                  painter: painter,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------
// Small icon button for the graph header
// ------------------------------------------------------------------
class _IconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _IconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            child: Icon(icon, size: 16, color: AppTheme.textSecondary),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------
// TimelinePainter — supports compact & comfortable dimensions
// ------------------------------------------------------------------
class _TimelinePainter extends CustomPainter {
  final List<GitCommit> commits;
  final _GraphLayout layout;
  final _GraphDimensions dims;

  late final double _textX;

  _TimelinePainter(
    this.commits, {
    required this.layout,
    required this.dims,
  }) {
    _textX = dims.leftMargin + (layout.maxLane + 2) * dims.laneWidth + 16;
  }

  Size calculateSize() {
    final width = dims.leftMargin + (layout.maxLane + 2) * dims.laneWidth + dims.rightMargin;
    final height = dims.topMargin + commits.length * dims.rowHeight + dims.bottomMargin;
    return Size(width, height);
  }

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);
    _drawConnections(canvas);
    _drawCommits(canvas, size);
  }

  void _drawBackground(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppTheme.borderStrong.withValues(alpha: dims.gridAlpha)
      ..strokeWidth = 0.6;

    for (double y = dims.topMargin; y < size.height - dims.bottomMargin; y += dims.rowHeight) {
      canvas.drawLine(
        Offset(dims.leftMargin - 12, y),
        Offset(size.width - dims.rightMargin + 40, y),
        gridPaint,
      );
    }

    for (int lane = 0; lane <= layout.maxLane + 1; lane++) {
      final x = dims.leftMargin + lane * dims.laneWidth;
      canvas.drawLine(
        Offset(x, dims.topMargin - 6),
        Offset(x, size.height - dims.bottomMargin + 6),
        gridPaint,
      );
    }

    final textAreaPaint = Paint()
      ..color = AppTheme.bgElevated.withValues(alpha: dims.gridAlpha);
    canvas.drawRect(
      Rect.fromLTWH(_textX - 8, 0, size.width - _textX + 8, size.height),
      textAreaPaint,
    );
  }

  void _drawConnections(Canvas canvas) {
    final paint = Paint()
      ..strokeWidth = dims.connectionStroke
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < commits.length; i++) {
      final child = commits[i];
      final childY = dims.topMargin + i * dims.rowHeight;
      final childLane = layout.commitLanes[child.id] ?? 0;
      final childX = dims.leftMargin + childLane * dims.laneWidth;
      final childColor = layout.colorForCommit(child);

      for (final parentId in child.parentIds) {
        final pi = commits.indexWhere((c) => c.id == parentId);
        if (pi < 0) continue;

        final parentY = dims.topMargin + pi * dims.rowHeight;
        final parentLane = layout.commitLanes[parentId] ?? 0;
        final parentX = dims.leftMargin + parentLane * dims.laneWidth;

        paint.color = childColor.withValues(alpha: dims.connectionAlpha);

        if (childLane == parentLane) {
          canvas.drawLine(
            Offset(childX, childY),
            Offset(parentX, parentY),
            paint,
          );
        } else {
          final path = Path();
          path.moveTo(childX, childY);
          final midY = (childY + parentY) / 2;
          final cp1y = childY + (midY - childY) * 0.5;
          final cp2y = parentY - (parentY - midY) * 0.5;
          path.cubicTo(childX, cp1y, parentX, cp2y, parentX, parentY);
          canvas.drawPath(path, paint);
        }
      }
    }
  }

  void _drawCommits(Canvas canvas, Size size) {
    for (int i = 0; i < commits.length; i++) {
      final c = commits[i];
      final y = dims.topMargin + i * dims.rowHeight;
      final lane = layout.commitLanes[c.id] ?? 0;
      final x = dims.leftMargin + lane * dims.laneWidth;
      final color = layout.colorForCommit(c);

      // Glow
      canvas.drawCircle(
        Offset(x, y),
        10,
        Paint()
          ..color = color.withValues(alpha: 0.06)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );

      // Node fill
      canvas.drawCircle(Offset(x, y), dims.nodeRadius, Paint()..color = color);

      // Highlight
      canvas.drawCircle(
        Offset(x - 1.2, y - 1.2),
        dims.nodeRadius * 0.45,
        Paint()..color = Colors.white.withValues(alpha: 0.25),
      );

      // Stroke
      canvas.drawCircle(
        Offset(x, y),
        dims.nodeRadius,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.75)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );

      // HEAD ring
      if (c.head) {
        canvas.drawCircle(
          Offset(x, y),
          dims.nodeRadius + 5.5,
          Paint()
            ..color = const Color(0xFFFBBF24)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6,
        );
      }

      // Branch pills (left side, stacked to the left)
      double pillX = x - 10;
      for (final b in c.branchNames) {
        final bare = _GraphLayout._bareName(b);
        final bc = layout.colorForBranchName(b);
        final tp = TextPainter(
          text: TextSpan(
            text: bare,
            style: TextStyle(
              color: bc.computeLuminance() > 0.5 ? Colors.black : Colors.white,
              fontSize: dims.pillFontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final pillW = math.max(tp.width + dims.pillHPad * 2, dims.pillMinWidth).toDouble();
        final pillH = dims.pillHeight;
        pillX -= pillW + 3;

        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(pillX, y - pillH / 2, pillW, pillH),
            Radius.circular(pillH / 2),
          ),
          Paint()..color = bc.withValues(alpha: 0.92),
        );
        tp.paint(canvas, Offset(pillX + dims.pillHPad, y - tp.height / 2));
      }

      // Hash
      final hashTp = TextPainter(
        text: TextSpan(
          text: c.shortId,
          style: TextStyle(
            color: AppTheme.textMuted,
            fontSize: dims.hashFontSize,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      hashTp.paint(canvas, Offset(_textX, y - hashTp.height / 2));

      // Message
      final msg = c.message.length > 60
          ? '${c.message.substring(0, 57)}...'
          : c.message;
      final msgTp = TextPainter(
        text: TextSpan(
          text: msg,
          style: TextStyle(
            color: AppTheme.text,
            fontSize: dims.messageFontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width - _textX - 50);
      msgTp.paint(canvas, Offset(_textX + 52, y - msgTp.height / 2));

      // Meta
      final metaTp = TextPainter(
        text: TextSpan(
          text: '${c.authorName}  ·  ${_fmtDate(c.commitTime)}',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: dims.metaFontSize,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      metaTp.paint(
        canvas,
        Offset(_textX + 52, y + msgTp.height / 2 + 3),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
