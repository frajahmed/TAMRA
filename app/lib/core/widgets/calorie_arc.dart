import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Arc gauge for the day's calories: fills up with what was eaten, shows the remaining
/// value in the centre. Going over the budget keeps the normal colour (never punishing).
class CalorieArc extends StatelessWidget {
  /// Creates the gauge; [progress] is eaten / budget (values above 1 are drawn as full).
  const CalorieArc({
    super.key,
    required this.progress,
    required this.value,
    required this.label,
  });

  /// Eaten divided by budget; 0 when there is no budget.
  final double progress;

  /// Big text in the centre, e.g. "1 230 kcal".
  final String value;

  /// Small text under [value], e.g. "left" or "over".
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      label: '$value $label',
      excludeSemantics: true,
      child: SizedBox(
      width: 220,
      height: 170,
      child: CustomPaint(
        painter: _ArcPainter(
          progress: progress.clamp(0, 1).toDouble(),
          track: colors.border,
          fill: colors.progress,
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.only(top: 56),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topCenter,
            child: Column(
              children: [
                Text(
                  value,
                  key: const Key('calorie-value'),
                  style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(label, style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary)),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter({required this.progress, required this.track, required this.fill});

  final double progress;
  final Color track;
  final Color fill;

  static const _sweep = math.pi * 4 / 3; // 240°
  static const _start = math.pi * 5 / 6; // starts lower left

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 16.0;
    final radius = math.min(size.width / 2, size.height * 0.6) - stroke;
    final rect = Rect.fromCircle(center: Offset(size.width / 2, size.height * 0.6), radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, _start, _sweep, false, paint..color = track);
    if (progress > 0) {
      canvas.drawArc(rect, _start, _sweep * progress, false, paint..color = fill);
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.progress != progress || old.track != track || old.fill != fill;
}
