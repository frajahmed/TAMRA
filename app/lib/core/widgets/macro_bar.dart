import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Thin progress bar for one macronutrient with its name and grams.
class MacroBar extends StatelessWidget {
  /// Creates the bar; [target] null shows only the eaten grams and an empty bar.
  const MacroBar({
    super.key,
    required this.label,
    required this.amountText,
    required this.grams,
    required this.color,
    this.target,
  });

  /// Name of the macro ("Protein").
  final String label;

  /// Formatted grams, e.g. "45 / 130 g".
  final String amountText;

  /// Eaten grams.
  final double grams;

  /// Target in grams, if known.
  final int? target;

  /// The macro's colour from [AppColors].
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final targetValue = target;
    final progress = targetValue == null || targetValue <= 0
        ? 0.0
        : (grams / targetValue).clamp(0, 1).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: colors.textSecondary)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            color: color,
            backgroundColor: colors.border,
          ),
        ),
        const SizedBox(height: 6),
        Text(amountText, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
