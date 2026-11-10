import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/settings_provider.dart';
import 'thumbnail_widget.dart';
import 'scale_button.dart';

/// Diameter of the paper label as a fraction of the disc.
///
/// A 12" label is about a third of the record. Under the full player
/// that fraction would shrink the cover to a speck, so the label grows
/// as [size] shrinks, down to the 44px mini-player art.
@visibleForTesting
double vinylLabelFraction(double size) {
  final t = ((size - 44) / (320 - 44)).clamp(0.0, 1.0);
  return 0.64 + (0.38 - 0.64) * t;
}

/// Spindle hole. A real 12" hole is ~2.6% of the disc; the clamp keeps
/// it visible on the 44px mini player.
@visibleForTesting
double vinylSpindleDiameter(double discSize) {
  return (discSize * 0.026).clamp(3.0, 12.0);
}

/// Pivot and stylus of the tonearm, in the widget's square.
///
/// The pivot sits in the top-right corner, off the platter. The stylus
/// rests on the groove band, outside the paper label.
@visibleForTesting
class VinylTonearmAnchors {
  final Offset pivot;
  final Offset stylus;

  const VinylTonearmAnchors({required this.pivot, required this.stylus});
}

@visibleForTesting
VinylTonearmAnchors vinylTonearmAnchors(double size, double labelFraction) {
  final center = Offset(size / 2, size / 2);
  final radius = size / 2;
  final labelRadius = radius * labelFraction;
  final grooveMid = (labelRadius + radius * 0.055 + radius * 0.955) / 2;
  // Upper-right of the groove field, so the arm crosses the rim on a diagonal.
  const angle = -0.78;
  return VinylTonearmAnchors(
    pivot: Offset(size * 0.90, size * 0.11),
    stylus: center + Offset(math.cos(angle), math.sin(angle)) * grooveMid,
  );
}

class VinylArtwork extends ConsumerStatefulWidget {
  final String? imageUrl;
  final double size;
  final bool isPlaying;
  final bool useShadow;
  final VoidCallback? onTap;
  final String? tooltipMessage;

  const VinylArtwork({
    super.key,
    required this.imageUrl,
    required this.size,
    required this.isPlaying,
    this.useShadow = true,
    this.onTap,
    this.tooltipMessage,
  });

  @override
  ConsumerState<VinylArtwork> createState() => _VinylArtworkState();
}

class _VinylArtworkState extends ConsumerState<VinylArtwork>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    );
    if (widget.isPlaying && !ref.read(settingsProvider).reduceEffects) {
      _rotationController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant VinylArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    final reduceEffects = ref.read(settingsProvider).reduceEffects;
    if (reduceEffects) {
      _rotationController.stop();
      return;
    }
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _rotationController.repeat();
      } else {
        _rotationController.stop();
      }
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceEffects = ref.watch(
      settingsProvider.select((s) => s.reduceEffects),
    );

    if (reduceEffects && _rotationController.isAnimating) {
      _rotationController.stop();
    } else if (!reduceEffects &&
        widget.isPlaying &&
        !_rotationController.isAnimating) {
      _rotationController.repeat();
    }

    final fraction = vinylLabelFraction(widget.size);
    final labelSize = widget.size * fraction;
    final hole = vinylSpindleDiameter(widget.size);

    Widget disk = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: widget.useShadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipOval(
            child: Stack(
              fit: StackFit.expand,
              children: [
                RotationTransition(
                  turns: _rotationController,
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _VinylDiscPainter(labelFraction: fraction),
                      child: Center(
                        child: _VinylLabel(
                          imageUrl: widget.imageUrl,
                          labelSize: labelSize,
                          hole: hole,
                          reduceEffects: reduceEffects,
                        ),
                      ),
                    ),
                  ),
                ),
                // The lamp stays put. A highlight that spins reads as print on a CD.
                IgnorePointer(
                  child: CustomPaint(
                    painter: _VinylSheenPainter(labelFraction: fraction),
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
          // Outside the disc clip: the pivot lives in the corner, off the platter.
          IgnorePointer(
            child: CustomPaint(
              painter: _TonearmPainter(labelFraction: fraction),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );

    if (widget.tooltipMessage != null) {
      disk = Tooltip(message: widget.tooltipMessage!, child: disk);
    }

    if (widget.onTap != null) {
      disk = ScaleButton(onTap: widget.onTap, child: disk);
    }

    return disk;
  }
}

class _VinylLabel extends StatelessWidget {
  const _VinylLabel({
    required this.imageUrl,
    required this.labelSize,
    required this.hole,
    required this.reduceEffects,
  });

  final String? imageUrl;
  final double labelSize;
  final double hole;
  final bool reduceEffects;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: labelSize,
      height: labelSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: labelSize,
            height: labelSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: reduceEffects
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: labelSize * 0.06,
                        spreadRadius: 0.5,
                      ),
                    ],
            ),
            foregroundDecoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF101010),
                width: (labelSize * 0.015).clamp(1.0, 2.5),
              ),
            ),
            child: ThumbnailWidget(
              imageUrl: imageUrl,
              size: labelSize,
              shape: ThumbnailShape.circle,
            ),
          ),
          Container(
            width: hole,
            height: hole,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF0A0A0A),
              border: Border.fromBorderSide(
                BorderSide(color: Color(0x66FFFFFF), width: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Black PVC, dead wax, and the groove field. The label is painted on top.
class _VinylDiscPainter extends CustomPainter {
  const _VinylDiscPainter({required this.labelFraction});

  final double labelFraction;

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = side / 2;
    final labelRadius = radius * labelFraction;

    final disc = Paint()
      ..shader = RadialGradient(
        colors: const [
          Color(0xFF2A2A2A),
          Color(0xFF161616),
          Color(0xFF0E0E0E),
          Color(0xFF1A1A1A),
        ],
        stops: const [0.0, 0.46, 0.88, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, disc);

    final grooveInner = labelRadius + radius * 0.055;
    final grooveOuter = radius * 0.955;
    final ring = Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(Rect.fromCircle(center: center, radius: grooveOuter))
      ..addOval(Rect.fromCircle(center: center, radius: grooveInner));

    canvas.save();
    canvas.clipPath(ring);
    final groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = side < 80 ? 0.45 : 0.65;
    final step = (side * 0.0075).clamp(1.35, 2.8);
    for (var r = grooveOuter - 0.5; r > grooveInner; r -= step) {
      final wave = math.sin(r / radius * math.pi * 14);
      final alpha = 0.03 + 0.06 * (wave * 0.5 + 0.5);
      groove.color = Color.fromRGBO(255, 255, 255, alpha);
      canvas.drawCircle(center, r, groove);
    }
    canvas.restore();

    final hairline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = side < 80 ? 0.6 : 0.9
      ..color = const Color(0x24FFFFFF);
    // Lead-in at the rim, run-out just outside the label.
    canvas.drawCircle(center, radius * 0.978, hairline);
    canvas.drawCircle(center, labelRadius + radius * 0.028, hairline);

    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFF000000);
    canvas.drawCircle(center, radius - 0.5, edge);
  }

  @override
  bool shouldRepaint(covariant _VinylDiscPainter oldDelegate) {
    return oldDelegate.labelFraction != labelFraction;
  }
}

/// Fixed lamp on the groove ring. Kept out of the rotating layer.
class _VinylSheenPainter extends CustomPainter {
  const _VinylSheenPainter({required this.labelFraction});

  final double labelFraction;

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = side / 2;
    final labelRadius = radius * labelFraction;

    final ring = Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(Rect.fromCircle(center: center, radius: radius))
      ..addOval(Rect.fromCircle(center: center, radius: labelRadius));

    canvas.save();
    canvas.clipPath(ring);
    final sheenAlpha = side < 80 ? 0.10 : 0.16;
    final sheen = Paint()
      ..shader = SweepGradient(
        startAngle: -2.45,
        endAngle: -0.65,
        colors: [
          const Color(0x00FFFFFF),
          Color.fromRGBO(255, 255, 255, sheenAlpha),
          const Color(0x00FFFFFF),
        ],
        stops: const [0.0, 0.42, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, sheen);

    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = side < 80 ? 1.0 : 1.6
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x66FFFFFF), Color(0x18FFFFFF), Color(0x00000000)],
        stops: [0.0, 0.45, 0.85],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius - 0.8, rim);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _VinylSheenPainter oldDelegate) {
    return oldDelegate.labelFraction != labelFraction;
  }
}

/// Tonearm parked over the groove field. It does not spin with the disc.
class _TonearmPainter extends CustomPainter {
  const _TonearmPainter({required this.labelFraction});

  final double labelFraction;

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    final anchors = vinylTonearmAnchors(side, labelFraction);
    final pivot = anchors.pivot;
    final stylus = anchors.stylus;
    final delta = stylus - pivot;
    final length = delta.distance;
    if (length < 1) return;
    final along = delta / length;

    final pivotRadius = (side * 0.034).clamp(1.7, 15.0);
    final tube = (side * 0.015).clamp(1.05, 6.5);
    final headLength = (side * 0.058).clamp(2.8, 24.0);
    final overhang = (side * 0.016).clamp(1.1, 6.5);

    final toSpindle = Offset(side / 2, side / 2) - stylus;
    final inward = toSpindle / toSpindle.distance;
    var headDir = along * 0.62 + inward * 0.38;
    final headLen = headDir.distance;
    if (headLen < 0.001) return;
    headDir = headDir / headLen;
    final headNormal = Offset(-headDir.dy, headDir.dx);

    final headFront = stylus - headDir * overhang;
    final headBack = headFront - headDir * headLength;
    final tubeStart = pivot + along * (pivotRadius * 0.42);
    final tubeEnd = headBack + headDir * (headLength * 0.22);

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    final drop = Offset(side * 0.005, side * 0.011);
    canvas.drawLine(
      tubeStart + drop,
      tubeEnd + drop,
      Paint()
        ..color = const Color(0x59000000)
        ..strokeWidth = tube * 1.5
        ..strokeCap = StrokeCap.round,
    );

    final counterLength = (side * 0.058).clamp(2.4, 22.0);
    _drawRod(
      canvas,
      pivot - along * (pivotRadius + counterLength),
      pivot - along * (pivotRadius * 0.82),
      tube * 2.45,
      Paint()..color = const Color(0xFF3A3A3E),
      radiusFactor: 0.45,
    );
    _drawRod(
      canvas,
      pivot - along * (pivotRadius + counterLength * 0.78),
      pivot - along * (pivotRadius + counterLength * 0.42),
      tube * 2.45,
      Paint()..color = const Color(0xFF6E6E74),
      radiusFactor: 0.2,
    );

    // Dark edge so the tube stays visible on a light player, silver on the vinyl.
    canvas.drawLine(
      tubeStart,
      tubeEnd,
      Paint()
        ..color = const Color(0xFF2C2C30)
        ..strokeWidth = tube + math.max(0.8, tube * 0.35)
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      tubeStart,
      tubeEnd,
      Paint()
        ..color = const Color(0xFFD5D5DA)
        ..strokeWidth = tube
        ..strokeCap = StrokeCap.round,
    );
    final highlight = Offset(-along.dy, along.dx) * (tube * 0.22);
    canvas.drawLine(
      tubeStart + highlight,
      tubeEnd + highlight,
      Paint()
        ..color = const Color(0x80FFFFFF)
        ..strokeWidth = math.max(0.4, tube * 0.28)
        ..strokeCap = StrokeCap.round,
    );

    _drawRod(
      canvas,
      headBack,
      headFront,
      tube * 2.3,
      Paint()..color = const Color(0xFF161618),
      radiusFactor: 0.28,
    );
    _drawRod(
      canvas,
      headBack + headDir * (headLength * 0.16),
      headFront - headDir * (headLength * 0.2),
      tube * 1.05,
      Paint()..color = const Color(0xFFC6C6CB),
      radiusFactor: 0.35,
    );

    final needleWidth = math.max(0.7, tube * 0.42);
    final needle = Path()
      ..moveTo(stylus.dx, stylus.dy)
      ..lineTo(
        (headFront + headNormal * needleWidth).dx,
        (headFront + headNormal * needleWidth).dy,
      )
      ..lineTo(
        (headFront - headNormal * needleWidth).dx,
        (headFront - headNormal * needleWidth).dy,
      )
      ..close();
    canvas.drawPath(needle, Paint()..color = const Color(0xFFE8E8EC));
    canvas.drawCircle(
      stylus,
      math.max(0.7, side * 0.006),
      Paint()..color = const Color(0xFF0E0E10),
    );

    canvas.drawCircle(
      pivot,
      pivotRadius,
      Paint()..color = const Color(0xFF242428),
    );
    canvas.drawCircle(
      pivot,
      pivotRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.6, pivotRadius * 0.14)
        ..color = const Color(0xFFB0B0B6),
    );
    canvas.drawCircle(
      pivot,
      pivotRadius * 0.4,
      Paint()..color = const Color(0xFF4C4C52),
    );
    canvas.drawCircle(
      pivot,
      pivotRadius * 0.14,
      Paint()..color = const Color(0xFFD0D0D6),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TonearmPainter oldDelegate) {
    return oldDelegate.labelFraction != labelFraction;
  }
}

void _drawRod(
  Canvas canvas,
  Offset from,
  Offset to,
  double thickness,
  Paint paint, {
  double radiusFactor = 0.5,
}) {
  final delta = to - from;
  final length = delta.distance;
  if (length < 0.1 || thickness < 0.1) return;
  canvas.save();
  canvas.translate(from.dx, from.dy);
  canvas.rotate(math.atan2(delta.dy, delta.dx));
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(0, -thickness / 2, length, thickness),
      Radius.circular(thickness * radiusFactor),
    ),
    paint,
  );
  canvas.restore();
}
