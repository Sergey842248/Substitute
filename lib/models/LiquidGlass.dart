import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Eine Fläche aus „Liquid Glass“: Der Fragment-Shader bricht und färbt den
/// tatsächlichen Backdrop und zeichnet gerichtete Spiegelungen auf den Rand.
///
/// `ImageFilter.shader` benötigt Impeller. Auf Renderern ohne diesen Support
/// bleibt die Fläche benutzbar und erhält eine gezeichnete Glasoptik.
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

  /// Der Wert des Reglers (0–30). Der Shader verwendet einen sanften Blur,
  /// damit die durch die Linse gebrochene Szene erkennbar bleibt.
  final double blur;

  /// Wie stark der Rand den Hintergrund verzieht (px).
  final double refraction;

  /// Wie breit der gebogene Rand ist (px).
  final double bezel;

  /// Stärke des Farbsaums am Rand (px).
  final double dispersion;

  /// Stärke der spiegelnden Lichtreflexe.
  final double highlight;

  @override
  State<LiquidGlass> createState() => _LiquidGlassState();
}

class _LiquidGlassState extends State<LiquidGlass> {
  static Future<ui.FragmentProgram?>? _programFuture;

  static Future<ui.FragmentProgram?> _loadProgram() async {
    if (!ui.ImageFilter.isShaderFilterSupported) {
      debugPrint(
        'LiquidGlass: ImageFilter.shader wird von diesem Renderer nicht '
        'unterstützt; die gezeichnete Glas-Fallback-Optik wird verwendet.',
      );
      return null;
    }

    try {
      return await ui.FragmentProgram.fromAsset('shaders/liquid_glass.frag');
    } catch (error, stackTrace) {
      debugPrint('LiquidGlass: Shader konnte nicht geladen werden: $error');
      debugPrintStack(stackTrace: stackTrace);
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
  /// Float 0 und 1 sowie Sampler 0 setzt die Engine selbst.
  void _setUniforms(ui.FragmentShader shader) {
    shader.setFloat(2, widget.radius);
    shader.setFloat(3, widget.bezel);
    shader.setFloat(4, widget.refraction);
    shader.setFloat(5, widget.blur * 0.35);
    shader.setFloat(6, widget.dispersion);
    shader.setFloat(7, widget.highlight);
    shader.setFloat(8, widget.tint.r);
    shader.setFloat(9, widget.tint.g);
    shader.setFloat(10, widget.tint.b);
    shader.setFloat(11, widget.tint.a);
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
      } catch (error) {
        debugPrint('LiquidGlass: Shaderfilter fehlgeschlagen: $error');
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
                child: SizedBox(
                  height: widget.height,
                  child: Center(child: widget.child),
                ),
              )
            : _fallback(borderRadius),
      ),
    );
  }

  /// Visueller Fallback für Renderer, die keine Runtime-ImageFilter ausführen.
  /// Die echte Brechung gibt es im Shaderpfad; auch hier bleiben Bevel,
  /// gerichtete Glanzlichter und zwei optische Kanten deutlich sichtbar.
  Widget _fallback(BorderRadius borderRadius) {
    return BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: widget.blur, sigmaY: widget.blur),
      child: SizedBox(
        height: widget.height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Colors.white.withValues(alpha: .22),
                widget.tint,
                Colors.black.withValues(alpha: .10),
              ],
              stops: const <double>[0, .48, 1],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              IgnorePointer(
                child: CustomPaint(
                  painter: _GlassReflectionPainter(
                    borderRadius: borderRadius,
                    intensity: widget.highlight,
                  ),
                ),
              ),
              Center(child: widget.child),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassReflectionPainter extends CustomPainter {
  const _GlassReflectionPainter({
    required this.borderRadius,
    required this.intensity,
  });

  final BorderRadius borderRadius;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect bounds = Offset.zero & size;
    final RRect outer = borderRadius.toRRect(bounds);
    final double strength = intensity.clamp(0.0, 1.5).toDouble();

    // Broad, soft reflection on the upper-left part of the lens.
    final Rect upperGlint = Rect.fromLTWH(
      size.width * .10,
      size.height * .09,
      size.width * .54,
      size.height * .19,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(upperGlint, Radius.circular(size.height * .10)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: <Color>[
            Colors.white.withValues(alpha: .30 * strength),
            const Color(0xffd9f4ff).withValues(alpha: .13 * strength),
            Colors.white.withValues(alpha: 0),
          ],
          stops: const <double>[0, .40, 1],
        ).createShader(upperGlint)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // A restrained, warmer counter-reflection makes the glass read as curved.
    final Rect lowerGlint = Rect.fromLTWH(
      size.width * .46,
      size.height * .78,
      size.width * .36,
      size.height * .10,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(lowerGlint, Radius.circular(size.height * .08)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: <Color>[
            Colors.white.withValues(alpha: 0),
            const Color(0xffffedd4).withValues(alpha: .12 * strength),
            Colors.white.withValues(alpha: .20 * strength),
          ],
        ).createShader(lowerGlint)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // Main bright rim: the reflected highlight fades around the lower edge.
    canvas.drawRRect(
      outer.deflate(.7),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Colors.white.withValues(alpha: .82 * strength),
            const Color(0xffdff5ff).withValues(alpha: .34 * strength),
            Colors.white.withValues(alpha: .10 * strength),
            const Color(0xff8ba6b6).withValues(alpha: .34 * strength),
          ],
          stops: const <double>[0, .24, .68, 1],
        ).createShader(bounds),
    );

    final RRect inner = borderRadius
        .subtract(const BorderRadius.all(Radius.circular(1.8)))
        .resolve(TextDirection.ltr)
        .toRRect(bounds.deflate(2.1));
    canvas.drawRRect(
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .75
        ..color = Colors.white.withValues(alpha: .34 * strength),
    );

    // The shaded lower bevel gives the two bright rims a sense of thickness.
    canvas.drawRRect(
      outer.deflate(2.9),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Colors.transparent, Color(0x66000000)],
        ).createShader(bounds),
    );
  }

  @override
  bool shouldRepaint(_GlassReflectionPainter oldDelegate) =>
      oldDelegate.borderRadius != borderRadius ||
      oldDelegate.intensity != intensity;
}
