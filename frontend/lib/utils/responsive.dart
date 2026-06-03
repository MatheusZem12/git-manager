import 'package:flutter/material.dart';

/// Helper para escalar tamanhos de UI baseado na largura disponível.
class Responsive {
  Responsive._();

  /// Escala para a sidebar (baseada na largura da sidebar).
  static double sidebarScale(double width) {
    if (width < 220) return 0.72;
    if (width < 260) return 0.82;
    if (width < 300) return 0.92;
    if (width < 380) return 1.0;
    return 1.05;
  }

  /// Escala para o conteúdo principal (baseada na largura do body).
  static double bodyScale(double width) {
    if (width < 500) return 0.78;
    if (width < 700) return 0.88;
    if (width < 900) return 0.95;
    if (width < 1200) return 1.0;
    return 1.05;
  }

  /// Escala genérica.
  static double scale(double width, {double base = 1200}) {
    final s = width / base;
    if (s < 0.72) return 0.72;
    if (s > 1.1) return 1.1;
    return s;
  }

  /// Retorna fontSize escalado.
  static double font(double base, double scale) => (base * scale).clamp(9.0, 32.0);

  /// Retorna padding escalado.
  static double pad(double base, double scale) => (base * scale).clamp(2.0, 48.0);

  /// Retorna tamanho de ícone escalado.
  static double icon(double base, double scale) => (base * scale).clamp(12.0, 48.0);
}

/// Widget que fornece scale via builder, baseado na largura do pai.
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, double scale) builder;
  final double baseWidth;

  const ResponsiveBuilder({
    super.key,
    required this.builder,
    this.baseWidth = 1200,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = Responsive.scale(constraints.maxWidth, base: baseWidth);
        return builder(context, scale);
      },
    );
  }
}
