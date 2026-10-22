/// Shared UI components ported from the Android app's
/// `ui/components/` (Charts.kt, Common.kt): the fairness score
/// ring, stacked split bars, the hourly heatmap, and the color
/// palette used by the baby/caregiver dialogs.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'ui_helpers.dart';

/// The original app's color palette for babies/caregivers
/// (Common.kt `PALETTE`).
const List<int> kPalette = [
  0xFFE57373,
  0xFF64B5F6,
  0xFFFFD54F,
  0xFF81C784,
  0xFFBA68C8,
  0xFFFF8A65,
  0xFF4DB6AC,
  0xFF90A4AE,
];

/// Circular fairness score gauge, 0..100 — port of the Kotlin
/// `ScoreRing`: a 270° arc starting at 135°, colored by band,
/// with the score and the word "fairness" in the middle.
class ScoreRing extends StatelessWidget {
  const ScoreRing({super.key, required this.score, this.size = 120});

  final double? score;
  final double size;

  static Color colorFor(double score) {
    if (score >= 90) return const Color(0xFF2E9E5B);
    if (score >= 75) return const Color(0xFF7CB342);
    if (score >= 60) return const Color(0xFFE8A13D);
    return const Color(0xFFE05252);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _ScoreRingPainter(score),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                score?.round().toString() ?? '–',
                style: TextStyle(
                  fontSize: size * 0.25,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Text(
                'fairness',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScoreRingPainter extends CustomPainter {
  const _ScoreRingPainter(this.score);
  final double? score;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 14.0;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    const startAngle = 135 * math.pi / 180;
    const fullSweep = 270 * math.pi / 180;
    final track = Paint()
      ..color = Colors.grey.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, startAngle, fullSweep, false, track);
    final s = score;
    if (s != null) {
      final arc = Paint()
        ..color = ScoreRing.colorFor(s)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
          rect, startAngle, fullSweep * s.clamp(0, 100) / 100, false, arc);
    }
  }

  @override
  bool shouldRepaint(covariant _ScoreRingPainter old) => old.score != score;
}

/// One segment of a [SplitBar]: legend label, color, fraction 0..1.
typedef SplitSegment = ({String label, Color color, double fraction});

/// Stacked horizontal share bar with a legend — port of the
/// Kotlin `SplitBar`.
class SplitBar extends StatelessWidget {
  const SplitBar({super.key, required this.segments});

  final List<SplitSegment> segments;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Container(
            height: 22,
            color: Colors.grey.withValues(alpha: 0.25),
            child: Row(
              children: [
                for (final seg in segments)
                  if (seg.fraction > 0.005)
                    Expanded(
                      flex: (seg.fraction * 10000).round(),
                      child: Container(color: seg.color),
                    ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            for (final seg in segments)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: seg.color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${seg.label} ${(seg.fraction * 100).round()}%',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

/// One task's split between caregivers — port of the Kotlin
/// `TaskSplitRow` (a header line over a [SplitBar]).
class TaskSplitRow extends StatelessWidget {
  const TaskSplitRow({
    super.key,
    required this.emoji,
    required this.name,
    required this.shares,
  });

  final String emoji;
  final String name;
  final List<SplitSegment> shares;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 4),
          SplitBar(segments: shares),
        ],
      ),
    );
  }
}

/// N days × 24 hours heatmap of the dominant caregiver per cell —
/// port of the Kotlin `Heatmap`.
class Heatmap extends StatelessWidget {
  const Heatmap({
    super.key,
    required this.days,
    required this.cells,
    required this.colorForCaregiver,
  });

  /// Day-start epoch millis, ascending; row index in [cells].
  final List<int> days;

  /// (dayIndex, hour) -> caregiverId with the most weighted points.
  final Map<(int, int), int> cells;
  final Color Function(int caregiverId) colorForCaregiver;

  @override
  Widget build(BuildContext context) {
    final variant = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // hour header (labels at 00/06/12/18, as in the original)
        Row(
          children: [
            const SizedBox(width: 34),
            for (final h in [0, 6, 12, 18])
              SizedBox(
                width: 48,
                child: Text(
                  h.toString().padLeft(2, '0'),
                  style: TextStyle(fontSize: 9, color: variant),
                ),
              ),
          ],
        ),
        for (var di = 0; di < days.length; di++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Row(
              children: [
                SizedBox(
                  width: 34,
                  child: Text(
                    _weekdayShort(days[di]),
                    style: TextStyle(fontSize: 9, color: variant),
                  ),
                ),
                for (var h = 0; h < 24; h++)
                  Container(
                    width: 13,
                    height: 13,
                    padding: const EdgeInsets.all(1),
                    child: Container(
                      decoration: BoxDecoration(
                        color: cells[(di, h)] != null
                            ? colorForCaregiver(cells[(di, h)]!)
                            : Colors.grey.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  static String _weekdayShort(int millis) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[
        DateTime.fromMillisecondsSinceEpoch(millis).weekday - 1];
  }
}

/// Row of palette color dots with a white center dot on the
/// selected one — port of the Kotlin `ColorPicker`.
class ColorPickerRow extends StatelessWidget {
  const ColorPickerRow({
    super.key,
    required this.selected,
    required this.onPick,
  });

  final int selected;
  final void Function(int color) onPick;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final c in kPalette)
          GestureDetector(
            onTap: () => onPick(c),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: colorFromInt(c),
                shape: BoxShape.circle,
              ),
              child: c == selected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
          ),
      ],
    );
  }
}

/// Baby selector shared by the tabs (the original's `BabyChips`,
/// in the Flutter app's existing dropdown/headline form).
class BabyPicker extends StatelessWidget {
  const BabyPicker({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final babies = controller.joinedBabies;
    if (babies.length <= 1) {
      return Text(
        babies.isEmpty ? '' : babies.first.name,
        style: Theme.of(context).textTheme.headlineSmall,
      );
    }
    return DropdownButton<int>(
      value: controller.selectedBaby?.id,
      items: babies
          .map((b) => DropdownMenuItem(value: b.id, child: Text(b.name)))
          .toList(),
      onChanged: (id) {
        if (id != null) controller.selectBaby(id);
      },
    );
  }
}
