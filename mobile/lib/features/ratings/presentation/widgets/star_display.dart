import 'package:flutter/material.dart';

/// Displays a row of 5 stars filled proportionally to [value].
/// Supports half-stars. Optionally shows count text.
class StarDisplay extends StatelessWidget {
  const StarDisplay({
    super.key,
    required this.value,
    this.count,
    this.size = 16.0,
    this.showCount = true,
  });

  final double value;
  final int? count;
  final double size;
  final bool showCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Stars (always LTR)
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (i) {
              final star = i + 1;
              final filled = value >= star;
              final half   = !filled && value >= star - 0.5;
              return Icon(
                filled
                    ? Icons.star_rounded
                    : half
                        ? Icons.star_half_rounded
                        : Icons.star_outline_rounded,
                color: filled || half ? const Color(0xFFF59E0B) : const Color(0xFF475569),
                size: size,
              );
            }),
          ),
        ),

        if (showCount && count != null) ...[
          const SizedBox(width: 6),
          Text(
            '${value.toStringAsFixed(1)} (${count!})',
            style: TextStyle(
              fontSize: size * 0.75,
              color: const Color(0xFF94A3B8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}
