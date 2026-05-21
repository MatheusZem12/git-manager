import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/git_commit.dart';
import '../services/api_service.dart';
import '../theme.dart';

/// Tela de timeline gráfica interativa para visualização de commits e branches.
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
  bool _loading = true;
  String? _error;

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

  @override
  Widget build(BuildContext context) {
    super.build(context);

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
    if (_commits.isEmpty) {
      return const Center(
        child: Text('Nenhum commit para exibir',
            style: TextStyle(color: AppTheme.textMuted)),
      );
    }

    return _GraphView(commits: _commits);
  }
}

// ------------------------------------------------------------------
// Retry button — estilo elegante
// ------------------------------------------------------------------
class _RetryButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _RetryButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.borderStrong),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.refresh, size: 16, color: AppTheme.textSecondary),
              SizedBox(width: 8),
              Text(
                'Tentar novamente',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------
// GraphView — contém o InteractiveViewer + CustomPaint
// ------------------------------------------------------------------
class _GraphView extends StatelessWidget {
  final List<GitCommit> commits;

  const _GraphView({required this.commits});

  @override
  Widget build(BuildContext context) {
    final painter = _TimelinePainter(commits);
    final size = painter.calculateSize();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.bg.withValues(alpha: 0.95),
            AppTheme.bgElevated.withValues(alpha: 0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderStrong.withValues(alpha: 0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InteractiveViewer(
        boundaryMargin: const EdgeInsets.all(200),
        minScale: 0.1,
        maxScale: 5.0,
        constrained: false,
        child: Container(
          alignment: Alignment.center,
          constraints: BoxConstraints(
            minWidth: size.width,
            minHeight: size.height,
          ),
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: CustomPaint(
              size: size,
              painter: painter,
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------
// TimelinePainter — desenha o grafo completo no Canvas
// ------------------------------------------------------------------
class _TimelinePainter extends CustomPainter {
  final List<GitCommit> commits;

  // ---- Layout ----
  static const double _laneWidth = 56.0;
  static const double _rowHeight = 76.0;
  static const double _leftMargin = 140.0;
  static const double _topMargin = 40.0;
  static const double _bottomMargin = 40.0;
  static const double _rightMargin = 420.0;
  static const double _nodeRadius = 7.0;

  // ---- Computed ----
  final Map<String, int> _commitLanes = {};
  final Map<String, Color> _laneColor = {};
  final Map<String, Color> _branchColor = {};
  late final int _maxLane;
  late final double _textX;

  _TimelinePainter(this.commits) {
    _assignLanesAndColors();
    _maxLane = _commitLanes.isEmpty
        ? 0
        : _commitLanes.values.reduce(math.max);
    _textX = _leftMargin + (_maxLane + 2) * _laneWidth + 28;
  }

  Size calculateSize() {
    final width = _leftMargin + (_maxLane + 2) * _laneWidth + _rightMargin;
    final height = _topMargin + commits.length * _rowHeight + _bottomMargin;
    return Size(math.max(width, 900), math.max(height, 400));
  }

  // ----------------------------------------------------------------
  // Lane assignment
  // ----------------------------------------------------------------
  void _assignLanesAndColors() {
    // 1) Mapeia branch -> lane
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

    // 2) Atribui lanes aos commits (do mais antigo para o mais novo)
    //    commits[0] = mais novo, commits[last] = mais antigo
    for (int i = commits.length - 1; i >= 0; i--) {
      final c = commits[i];
      int lane = -1;

      // a) lane de branch explícita
      for (final b in c.branchNames) {
        final l = branchLane[_bareName(b).toLowerCase()];
        if (l != null) {
          lane = lane == -1 || l < lane ? l : lane;
        }
      }

      // b) herda do primeiro pai que já tenha lane
      if (lane == -1) {
        for (final pid in c.parentIds) {
          final pl = _commitLanes[pid];
          if (pl != null) {
            lane = pl;
            break;
          }
        }
      }

      // c) fallback
      if (lane == -1) lane = 0;
      _commitLanes[c.id] = lane;
    }

    // 3) Calcula maxLane e atribui paleta de cores
    final maxLane = _commitLanes.isEmpty
        ? 0
        : _commitLanes.values.reduce(math.max);

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

    for (int l = 0; l <= maxLane; l++) {
      _laneColor[_laneKey(l)] = lanePalette[l % lanePalette.length];
    }

    // 4) Cores especiais por nome de branch
    for (final b in ordered) {
      final c = _namedBranchColor(b) ??
          HSLColor.fromAHSL(
            1.0,
            (ordered.indexOf(b) * 47.0) % 360,
            0.78,
            0.72,
          ).toColor();
      _branchColor[b.toLowerCase()] = c;
    }
  }

  static String _laneKey(int lane) => 'lane_$lane';

  int _branchPriority(String name) {
    final lower = name.toLowerCase();
    final p = ['main', 'master', 'develop', 'dev'];
    final i = p.indexOf(lower);
    return i >= 0 ? i : 999;
  }

  Color? _namedBranchColor(String name) {
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

  String _bareName(String b) => b.replaceAll(' (remoto)', '').trim();

  Color _colorForCommit(GitCommit c) {
    final lane = _commitLanes[c.id] ?? 0;
    return _laneColor[_laneKey(lane)] ?? AppTheme.accent;
  }

  Color _colorForBranchName(String name) {
    return _branchColor[_bareName(name).toLowerCase()] ?? _colorForCommit(
      commits.firstWhere(
        (c) => c.branchNames.contains(name),
        orElse: () => commits.first,
      ),
    );
  }

  String _fmtDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}'
        ' ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  // ----------------------------------------------------------------
  // Paint
  // ----------------------------------------------------------------
  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);
    _drawConnections(canvas);
    _drawCommits(canvas, size);
  }

  void _drawBackground(Canvas canvas, Size size) {
    // Fundo gradiente sutil já é feito pelo Container, aqui desenhamos apenas
    // um grid de referência bem discreto
    final gridPaint = Paint()
      ..color = AppTheme.borderStrong.withValues(alpha: 0.12)
      ..strokeWidth = 0.8;

    // Linhas horizontais
    for (double y = _topMargin; y < size.height - _bottomMargin; y += _rowHeight) {
      canvas.drawLine(
        Offset(_leftMargin - 20, y),
        Offset(size.width - _rightMargin + 80, y),
        gridPaint,
      );
    }

    // Linhas verticais das lanes
    for (int lane = 0; lane <= _maxLane + 1; lane++) {
      final x = _leftMargin + lane * _laneWidth;
      canvas.drawLine(
        Offset(x, _topMargin - 10),
        Offset(x, size.height - _bottomMargin + 10),
        gridPaint,
      );
    }

    // Área do texto com fundo sutil
    final textAreaPaint = Paint()
      ..color = AppTheme.bgElevated.withValues(alpha: 0.15);
    canvas.drawRect(
      Rect.fromLTWH(_textX - 12, 0, size.width - _textX + 12, size.height),
      textAreaPaint,
    );
  }

  void _drawConnections(Canvas canvas) {
    final paint = Paint()
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < commits.length; i++) {
      final child = commits[i];
      final childY = _topMargin + i * _rowHeight;
      final childLane = _commitLanes[child.id] ?? 0;
      final childX = _leftMargin + childLane * _laneWidth;
      final childColor = _colorForCommit(child);

      for (final parentId in child.parentIds) {
        final pi = commits.indexWhere((c) => c.id == parentId);
        if (pi < 0) continue; // pai fora do limite

        final parentY = _topMargin + pi * _rowHeight;
        final parentLane = _commitLanes[parentId] ?? 0;
        final parentX = _leftMargin + parentLane * _laneWidth;

        paint.color = childColor.withValues(alpha: 0.45);

        if (childLane == parentLane) {
          // Linha reta vertical
          canvas.drawLine(
            Offset(childX, childY),
            Offset(parentX, parentY),
            paint,
          );
        } else {
          // Curva suave entre lanes
          final path = Path();
          path.moveTo(childX, childY);
          final midY = (childY + parentY) / 2;
          // Control points para Bezier cúbico
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
      final y = _topMargin + i * _rowHeight;
      final lane = _commitLanes[c.id] ?? 0;
      final x = _leftMargin + lane * _laneWidth;
      final color = _colorForCommit(c);

      // ---- Glow sutil ao redor do nó ----
      canvas.drawCircle(
        Offset(x, y),
        16,
        Paint()
          ..color = color.withValues(alpha: 0.10)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );

      // ---- Nó principal ----
      canvas.drawCircle(Offset(x, y), _nodeRadius, Paint()..color = color);

      // ---- Brilho interno ----
      canvas.drawCircle(
        Offset(x - 2, y - 2),
        2.5,
        Paint()..color = Colors.white.withValues(alpha: 0.35),
      );

      // ---- Borda branca ----
      canvas.drawCircle(
        Offset(x, y),
        _nodeRadius,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );

      // ---- HEAD ring ----
      if (c.head) {
        canvas.drawCircle(
          Offset(x, y),
          13,
          Paint()
            ..color = const Color(0xFFFBBF24)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
      }

      // ---- Pills de branch (à esquerda do nó) ----
      double pillX = x - 18;
      for (final b in c.branchNames) {
        final bare = _bareName(b);
        final bc = _colorForBranchName(b);
        final tp = TextPainter(
          text: TextSpan(
            text: bare,
            style: TextStyle(
              color: bc.computeLuminance() > 0.5 ? Colors.black : Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final pillW = math.max(tp.width + 16, 38).toDouble();
        const pillH = 18.0;
        pillX -= pillW;

        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(pillX, y - pillH / 2, pillW, pillH),
            const Radius.circular(9),
          ),
          Paint()..color = bc,
        );
        tp.paint(canvas, Offset(pillX + 8, y - tp.height / 2));
      }

      // ---- Hash (curto) ----
      final hashTp = TextPainter(
        text: TextSpan(
          text: c.shortId,
          style: const TextStyle(
            color: AppTheme.textMuted,
            fontSize: 11,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      hashTp.paint(canvas, Offset(_textX, y - 15));

      // ---- Mensagem do commit ----
      final msg = c.message.length > 65
          ? '${c.message.substring(0, 62)}...'
          : c.message;
      final msgTp = TextPainter(
        text: TextSpan(
          text: msg,
          style: const TextStyle(
            color: AppTheme.text,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width - _textX - 80);
      msgTp.paint(canvas, Offset(_textX + 72, y - 15));

      // ---- Autor + data ----
      final metaTp = TextPainter(
        text: TextSpan(
          text: '${c.authorName}  ·  ${_fmtDate(c.commitTime)}',
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 11.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      metaTp.paint(canvas, Offset(_textX + 72, y + 5));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
