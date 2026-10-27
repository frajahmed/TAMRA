import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Simple bar chart (one bar per label) with an optional target line.
///
/// Drawn by hand so the app needs no chart package; screen readers get [semanticLabel].
class BarChart extends StatelessWidget {
  /// Creates the chart; [values] and [labels] have the same length.
  const BarChart({
    super.key,
    required this.values,
    required this.labels,
    required this.semanticLabel,
    this.target,
    this.secondaryValues,
    this.height = 180,
  });

  /// Height of each bar in data units.
  final List<double> values;

  /// Optional second, thinner bar per label (e.g. burned kcal next to eaten kcal).
  final List<double>? secondaryValues;

  /// Text under each bar (e.g. the weekday).
  final List<String> labels;

  /// Optional horizontal goal line in data units.
  final double? target;

  /// What a screen reader says for the whole chart.
  final String semanticLabel;

  /// Height of the drawing area.
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Semantics(
      label: semanticLabel,
      container: true,
      child: ExcludeSemantics(
        child: Column(
          children: [
            SizedBox(
              height: height,
              width: double.infinity,
              child: CustomPaint(
                painter: _BarPainter(
                  values: values,
                  secondary: secondaryValues,
                  secondaryColor: colors.brand,
                  target: target,
                  bar: colors.progress,
                  targetLine: colors.brand,
                  grid: colors.border,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                for (final label in labels)
                  Expanded(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.textSecondary, fontSize: 12),
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

class _BarPainter extends CustomPainter {
  _BarPainter({
    required this.values,
    required this.secondary,
    required this.secondaryColor,
    required this.target,
    required this.bar,
    required this.targetLine,
    required this.grid,
  });

  final List<double> values;
  final List<double>? secondary;
  final Color secondaryColor;
  final double? target;
  final Color bar;
  final Color targetLine;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      Paint()..color = grid,
    );
    if (values.isEmpty) return;

    final extra = secondary;
    final highest = [...values, ...?extra, target ?? 0].reduce(math.max);
    final maxY = highest <= 0 ? 1.0 : highest * 1.15;
    final slot = size.width / values.length;
    final mainWidth = slot * (extra == null ? 0.55 : 0.38);
    final extraWidth = slot * 0.18;
    final groupWidth = mainWidth + (extra == null ? 0 : extraWidth + 2);

    void drawBar(double left, double width, double value, Color color) {
      final barHeight = (value.clamp(0, maxY) / maxY) * size.height;
      if (barHeight <= 0) return;
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(left, size.height - barHeight, width, barHeight),
          topLeft: const Radius.circular(6),
          topRight: const Radius.circular(6),
        ),
        Paint()..color = color,
      );
    }

    for (var index = 0; index < values.length; index++) {
      final left = slot * index + (slot - groupWidth) / 2;
      drawBar(left, mainWidth, values[index], bar);
      if (extra != null && index < extra.length) {
        drawBar(left + mainWidth + 2, extraWidth, extra[index], secondaryColor);
      }
    }

    final goal = target;
    if (goal != null && goal > 0) {
      final y = size.height - (goal / maxY) * size.height;
      final dash = Paint()
        ..color = targetLine
        ..strokeWidth = 2;
      for (var x = 0.0; x < size.width; x += 10) {
        canvas.drawLine(Offset(x, y), Offset(math.min(x + 6, size.width), y), dash);
      }
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.values != values ||
      old.secondary != secondary ||
      old.target != target ||
      old.bar != bar;
}

/// Line chart for a value over time (e.g. weight); works with 0, 1 or many points.
class LineChart extends StatelessWidget {
  /// Creates the chart; [values] are in time order (oldest first).
  const LineChart({
    super.key,
    required this.values,
    required this.semanticLabel,
    this.height = 160,
  });

  /// The values from oldest to newest.
  final List<double> values;

  /// What a screen reader says for the whole chart.
  final String semanticLabel;

  /// Height of the drawing area.
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Semantics(
      label: semanticLabel,
      container: true,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _LinePainter(values: values, line: colors.progress, grid: colors.border),
        ),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({required this.values, required this.line, required this.grid});

  final List<double> values;
  final Color line;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()..color = grid;
    for (var step = 0; step <= 2; step++) {
      final y = size.height * step / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    if (values.isEmpty) return;

    final low = values.reduce(math.min);
    final high = values.reduce(math.max);
    final span = high - low < 1 ? 1.0 : high - low;
    final bottom = low - span * 0.2;
    final range = span * 1.4;

    Offset point(int index) {
      final x = values.length == 1 ? size.width / 2 : size.width * index / (values.length - 1);
      final y = size.height - (values[index] - bottom) / range * size.height;
      return Offset(x, y);
    }

    final dot = Paint()..color = line;
    if (values.length == 1) {
      canvas.drawCircle(point(0), 5, dot);
      return;
    }
    final path = Path()..moveTo(point(0).dx, point(0).dy);
    for (var index = 1; index < values.length; index++) {
      path.lineTo(point(index).dx, point(index).dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(point(values.length - 1), 5, dot);
  }

  @override
  bool shouldRepaint(_LinePainter old) => old.values != values || old.line != line;
}
