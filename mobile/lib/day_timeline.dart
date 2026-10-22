/// Outlook-style 24-hour day timeline, ported from the Kotlin
/// TodayScreen's `DayTimeline`/`EntryBlock`: entries as
/// time-positioned blocks, drag a block to move it, drag its
/// bottom edge to resize it, overlapping entries side by side,
/// a red now-line on today's view, tap a block to edit it, and
/// tap an empty hour to add an entry there.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'fairness.dart' show startOfDay;
import 'models.dart';
import 'timeline_layout.dart';
import 'ui_helpers.dart';

class DayTimeline extends StatelessWidget {
  const DayTimeline({
    super.key,
    required this.dayStart,
    required this.entries,
    required this.caregiverById,
    required this.taskById,
    required this.scrollController,
    required this.onEditEntry,
    required this.onEmptyTap,
    required this.onEntryChanged,
  });

  /// Epoch millis of the displayed day's local 00:00.
  final int dayStart;

  /// The day's entries (any order; lanes are computed here).
  final List<LogEntry> entries;
  final Map<int, Caregiver> caregiverById;
  final Map<int, CareTask> taskById;
  final ScrollController scrollController;

  /// Tap on a block → open the edit form.
  final void Function(LogEntry entry) onEditEntry;

  /// Tap on an empty hour row → add an entry at that hour.
  final void Function(int hour) onEmptyTap;

  /// A drag/resize committed → persist via the repository.
  final void Function(LogEntry updated) onEntryChanged;

  @override
  Widget build(BuildContext context) {
    final lanes = assignLanes(entries);
    final scheme = Theme.of(context).colorScheme;
    final isToday =
        dayStart == startOfDay(DateTime.now().millisecondsSinceEpoch);
    final nowMin = (DateTime.now().millisecondsSinceEpoch - dayStart) / 60000.0;
    final showNow = isToday && nowMin >= 0 && nowMin <= kMinutesPerDay;

    return SingleChildScrollView(
      controller: scrollController,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // hour gutter
          SizedBox(
            width: 52,
            child: Column(
              children: [
                for (var h = 0; h < 24; h++)
                  SizedBox(
                    height: kHourHeight,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(
                          fmtHour(DateTime.fromMillisecondsSinceEpoch(
                              dayStart + h * 3600000)),
                          style: TextStyle(
                              fontSize: 11, color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // the day column
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SizedBox(
                  height: kHourHeight * 24,
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      // hour grid lines
                      for (var h = 0; h <= 24; h++)
                        Positioned(
                          top: h * kHourHeight,
                          left: 0,
                          right: 0,
                          height: 1,
                          child: IgnorePointer(
                            child: Container(
                              color:
                                  scheme.outlineVariant.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      // tap an empty hour → new entry (behind the blocks)
                      for (var h = 0; h < 24; h++)
                        Positioned(
                          top: h * kHourHeight,
                          left: 0,
                          right: 0,
                          height: kHourHeight,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => onEmptyTap(h),
                          ),
                        ),
                      // entry blocks
                      for (final e in entries)
                        _TimelineBlock(
                          key: ValueKey(e.id),
                          entry: e,
                          lane: lanes[e.id] ?? const LaneInfo(0, 1),
                          dayStart: dayStart,
                          dayWidth: constraints.maxWidth,
                          caregiver: caregiverById[e.caregiverId],
                          task: taskById[e.taskId],
                          onTap: () => onEditEntry(e),
                          onCommit: onEntryChanged,
                        ),
                      // now-line
                      if (showNow) ...[
                        Positioned(
                          top: nowMin / 60 * kHourHeight,
                          left: 0,
                          right: 0,
                          height: 2,
                          child: IgnorePointer(
                            child:
                                Container(color: const Color(0xFFE53935)),
                          ),
                        ),
                        Positioned(
                          top: nowMin / 60 * kHourHeight - 5,
                          left: 2,
                          width: 10,
                          height: 10,
                          child: IgnorePointer(
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Color(0xFFE53935),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineBlock extends StatefulWidget {
  const _TimelineBlock({
    super.key,
    required this.entry,
    required this.lane,
    required this.dayStart,
    required this.dayWidth,
    required this.caregiver,
    required this.task,
    required this.onTap,
    required this.onCommit,
  });

  final LogEntry entry;
  final LaneInfo lane;
  final int dayStart;
  final double dayWidth;
  final Caregiver? caregiver;
  final CareTask? task;
  final VoidCallback onTap;
  final void Function(LogEntry updated) onCommit;

  @override
  State<_TimelineBlock> createState() => _TimelineBlockState();
}

class _TimelineBlockState extends State<_TimelineBlock> {
  double _dragDy = 0;
  double _resizeDh = 0;
  bool _resizing = false;

  int get _startMin =>
      (widget.entry.startMillis - widget.dayStart) ~/ 60000;
  int get _durMin => widget.entry.durationMin;
  double get _baseTop => _startMin / 60 * kHourHeight;
  double get _baseHeight =>
      math.max(_durMin / 60 * kHourHeight, kMinBlockHeight);

  @override
  void didUpdateWidget(covariant _TimelineBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When the saved entry flows back in, drop the drag offsets so
    // they aren't applied twice — mirrors the Kotlin
    // `remember(entry.id, entry.startMillis/endMillis)` reset and
    // avoids a snap-back flicker between drop and the write landing.
    if (oldWidget.entry.startMillis != widget.entry.startMillis ||
        oldWidget.entry.endMillis != widget.entry.endMillis) {
      _dragDy = 0;
      _resizeDh = 0;
    }
  }

  void _onDragStart(DragStartDetails details) {
    // A touch starting in the bottom-edge zone resizes; anywhere
    // else moves. The zone is proportional (as in the Kotlin
    // block) so short blocks stay easy to grab and move.
    final handleZone = (_baseHeight * 0.25).clamp(10.0, 18.0);
    _resizing = details.localPosition.dy >= _baseHeight - handleZone;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0;
    if (delta == 0) return;
    setState(() {
      if (_resizing) {
        _resizeDh =
            math.max(_resizeDh + delta, kMinBlockHeight - _baseHeight);
      } else {
        _dragDy += delta;
      }
    });
  }

  void _onDragEnd(DragEndDetails details) {
    final e = widget.entry;
    if (_resizing) {
      final newDur = resizedDurationMin(
          startMin: _startMin, durationMin: _durMin, dhPx: _resizeDh);
      final newEnd = e.startMillis + newDur * 60000;
      if (newEnd != e.endMillis) {
        widget.onCommit(e.copyWith(endMillis: newEnd));
        // Offsets reset in didUpdateWidget when the save lands.
        setState(() => _resizing = false);
      } else {
        setState(() {
          _resizeDh = 0;
          _resizing = false;
        });
      }
    } else {
      final newStartMin = movedStartMin(
          startMin: _startMin, durationMin: _durMin, dyPx: _dragDy);
      final newStart = widget.dayStart + newStartMin * 60000;
      if (newStart != e.startMillis) {
        final dur = e.endMillis - e.startMillis;
        widget.onCommit(
            e.copyWith(startMillis: newStart, endMillis: newStart + dur));
        setState(() => _resizing = false);
      } else {
        setState(() => _dragDy = 0);
      }
    }
  }

  String get _chipLabel {
    if (_resizeDh != 0) {
      // Live duration while resizing (Kotlin chip).
      final preview = snapMinutes(_durMin + _resizeDh / kHourHeight * 60);
      return fmtDuration(math.max(preview, kSnapMinutes));
    }
    // Live start time while moving (Kotlin chip).
    final preview = movedStartMin(
            startMin: _startMin, durationMin: _durMin, dyPx: _dragDy)
        .clamp(0, 1439);
    return fmtTime(
        DateTime.fromMillisecondsSinceEpoch(widget.dayStart + preview * 60000));
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final laneCount = widget.lane.laneCount;
    final colWidth = widget.dayWidth / laneCount;
    final compact = laneCount > 1;
    final hPad = compact ? 4.0 : 7.0;
    final bg = widget.caregiver != null
        ? colorFromInt(widget.caregiver!.color)
        : Colors.grey;
    final dragging = _dragDy != 0 || _resizeDh != 0;

    return Positioned(
      left: widget.lane.lane * colWidth,
      top: _baseTop + _dragDy,
      width: colWidth - 3,
      height: _baseHeight + _resizeDh,
      child: GestureDetector(
        onTap: widget.onTap,
        onVerticalDragStart: _onDragStart,
        onVerticalDragUpdate: _onDragUpdate,
        onVerticalDragEnd: _onDragEnd,
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            children: [
              // one info line: "Dad • 🍼 Bottle feed • 7:00–7:15 PM"
              Padding(
                padding:
                    EdgeInsets.fromLTRB(hPad, 3, hPad, 2),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: widget.caregiver?.name ?? '?',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (widget.task != null)
                          TextSpan(
                              text:
                                  ' • ${widget.task!.emoji} ${widget.task!.name}'),
                        TextSpan(text: ' • ${fmtRange(e.start, e.end)}'),
                      ],
                    ),
                    style: TextStyle(
                        fontSize: compact ? 11 : 12, color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              // bottom-edge resize grip (visual cue; the gesture
              // detector above handles the actual resize)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 14,
                child: Center(
                  child: Container(
                    width: 30,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              // live chip while dragging: time for moves, duration
              // for resizes
              if (dragging)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _chipLabel,
                      style:
                          const TextStyle(fontSize: 10, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
