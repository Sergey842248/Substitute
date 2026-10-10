import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Eine Fläche aus „Liquid Glass“: Brechung, Farbsaum und Lichtkante, berechnet
/// von einem Fragment-Shader auf dem Hintergrund (`BackdropFilter`).
///
/// ## Voraussetzung
///
/// `ImageFilter.shader` gibt es nur mit **Impeller**. Ohne Impeller (oder wenn
/// der Shader nicht lädt) zeigt die Fläche stattdessen die einfache Variante
/// mit Blur und Tönung – die Leiste bleibt also in jedem Fall benutzbar.
class LiquidGlass extends StatefulWidget {
  const LiquidGlass({
    Key? key,
    required this.height,
    required this.child,
    required this.tint,
    this.radius = 32,
    this.blur = 16,
    this.refraction = 14,
    this.bezel = 20,
    this.dispersion = 2.5,
    this.highlight = 1.0,
  }) : super(key: key);

  final double height;
  final Widget child;

  /// Tönung des Glases; der Alpha-Wert bestimmt, wie stark sie ist.
  final Color tint;

  /// Eckenradius. Der Shader bekommt denselben Wert wie der Zuschnitt.
  final double radius;

  /// Der Wert des Reglers (0–30). Im Shader wird daraus ein sanfter Blur,
  /// weil Liquid Glass fast klar ist.
  final double blur;

  /// Wie stark der Rand den Hintergrund verzieht (px).
  final double refraction;

  /// Wie breit der gebogene Rand ist (px).
  final double bezel;

  /// Stärke des Farbsaums am Rand (px).
  final double dispersion;

  /// Stärke der Lichtkante.
  final double highlight;

  @override
  State<LiquidGlass> createState() => _LiquidGlassState();
}

class _LiquidGlassState extends State<LiquidGlass> {
  static Future<ui.FragmentProgram?>? _programFuture;

  static Future<ui.FragmentProgram?> _loadProgram() async {
    try {
      if (!ui.ImageFilter.isShaderFilterSupported) return null;
      return await ui.FragmentProgram.fromAsset('shaders/liquid_glass.frag');
    } catch (fehler) {
      debugPrint('LiquidGlass: Shader nicht verfügbar – $fehler');
      return null;
    }
  }

  ui.FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    _programFuture ??= _loadProgram();
    _programFuture!.then((ui.FragmentProgram? program) {
      if (!mounted || program == null) return;
      setState(() => _shader = program.fragmentShader());
    });
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  /// Die Reihenfolge entspricht den Uniforms in `liquid_glass.frag`.
  /// Float 0 und 1 (Größe) setzt die Engine selbst – deshalb ab 2.
  void _setUniforms(ui.FragmentShader s) {
    s.setFloat(2, widget.radius);
    s.setFloat(3, widget.bezel);
    s.setFloat(4, widget.refraction);
    s.setFloat(5, widget.blur * 0.35);
    s.setFloat(6, widget.dispersion);
    s.setFloat(7, widget.highlight);
    s.setFloat(8, widget.tint.r);
    s.setFloat(9, widget.tint.g);
    s.setFloat(10, widget.tint.b);
    s.setFloat(11, widget.tint.a);
  }

  @override
  Widget build(BuildContext context) {
    final BorderRadius borderRadius = BorderRadius.circular(widget.radius);

    ui.ImageFilter? filter;
    final ui.FragmentShader? shader = _shader;
    if (shader != null) {
      _setUniforms(shader);
      try {
        filter = ui.ImageFilter.shader(shader);
      } catch (fehler) {
        filter = null;
      }
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: .24),
            blurRadius: 24,
            spreadRadius: 1,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: filter != null
            ? BackdropFilter(
                filter: filter,
                child: Container(
                  height: widget.height,
                  alignment: Alignment.center,
                  child: widget.child,
                ),
              )
            : _fallback(borderRadius),
      ),
    );
  }

  /// Die bisherige Variante: Blur, Tönung und gezeichnete Kanten.
  Widget _fallback(BorderRadius borderRadius) {
    return BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: widget.blur, sigmaY: widget.blur),
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Colors.white.withValues(alpha: .26),
              widget.tint,
              Colors.black.withValues(alpha: .12),
            ],
            stops: const <double>[0, .48, 1],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            IgnorePointer(
              child: CustomPaint(
                painter: _GlassEdgePainter(borderRadius),
              ),
            ),
            Center(child: widget.child),
          ],
        ),
      ),
    );
  }
}

class _GlassEdgePainter extends CustomPainter {
  const _GlassEdgePainter(this.borderRadius);

  final BorderRadius borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final RRect outer = borderRadius.toRRect(Offset.zero & size);
    canvas.drawRRect(
      outer.deflate(.625),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.25
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xccffffff),
            Color(0x66dff5ff),
            Color(0x334b6370),
          ],
          stops: <double>[0, .38, 1],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_GlassEdgePainter oldDelegate) =>
      oldDelegate.borderRadius != borderRadius;
}