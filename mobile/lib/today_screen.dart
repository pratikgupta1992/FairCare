/// Today tab: the selected baby's day as an Outlook-style 24h
/// timeline (see [DayTimeline]), with the previous/next-day
/// navigation the Android app has, plus the add-entry button.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'day_timeline.dart';
import 'fairness.dart';
import 'log_entry_form.dart';
import 'models.dart';
import 'timeline_layout.dart';
import 'ui_helpers.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  /// Points the Today view at [dayStartMillis] next time it is
  /// built — the Calendar tab's "Open in Today view" action (the
  /// Kotlin app's `jumpToDay`). The day lives in the session
  /// state below, exactly like a day picked with the chevrons.
  static void jumpToDay(int dayStartMillis) {
    _TodayScreenState._sessionDayStart = startOfDay(dayStartMillis);
  }

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  /// Last viewed day, kept across tab switches within a session —
  /// the Kotlin app holds the selected day in its ViewModel, so it
  /// survives tab switches there too. Null until first build.
  static int? _sessionDayStart;

  late int _dayStart;
  final ScrollController _scroll = ScrollController();
  String? _scrollKey;

  @override
  void initState() {
    super.initState();
    _dayStart = _sessionDayStart ??
        startOfDay(DateTime.now().millisecondsSinceEpoch);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  bool get _isToday =>
      _dayStart == startOfDay(DateTime.now().millisecondsSinceEpoch);

  void _shiftDay(int delta) {
    setState(() {
      _dayStart += delta * const Duration(days: 1).inMilliseconds;
      _sessionDayStart = _dayStart;
    });
  }

  String get _dayLabel {
    final today = startOfDay(DateTime.now().millisecondsSinceEpoch);
    if (_dayStart == today) return 'Today';
    if (_dayStart == today - const Duration(days: 1).inMilliseconds) {
      return 'Yesterday';
    }
    final dt = DateTime.fromMillisecondsSinceEpoch(_dayStart);
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  /// Auto-scroll the timeline near "now" (today) or the day's first
  /// entry (other days), once per (baby, day) — mirrors the Kotlin
  /// `LaunchedEffect(dayStart)` scroll.
  void _maybeAutoScroll(int babyId, List<LogEntry> dayEntries) {
    final key = '$babyId:$_dayStart';
    if (_scrollKey == key) return;
    if (!_isToday && dayEntries.isEmpty) return; // wait for data
    _scrollKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final int targetHour;
      if (_isToday) {
        targetHour = DateTime.now().hour;
      } else {
        targetHour =
            ((dayEntries.first.startMillis - _dayStart) / 3600000).floor();
      }
      final offset = math.min(
        targetHour.clamp(0, 20) * kHourHeight,
        _scroll.position.maxScrollExtent,
      );
      _scroll.jumpTo(offset);
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final baby = controller.selectedBaby;
    if (baby == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
              'No baby yet. Create one — or join with a connect code — in the Babies tab.'),
        ),
      );
    }
    final repo = controller.repo;
    final dayEnd = _dayStart + const Duration(days: 1).inMilliseconds;
    final dayEntries = repo
        .entriesForBaby(baby.id)
        .where((e) => e.endMillis > _dayStart && e.startMillis < dayEnd)
        .toList()
      ..sort((a, b) => a.startMillis.compareTo(b.startMillis));
    final totalMin = dayEntries.fold(0, (sum, e) => sum + e.durationMin);
    _maybeAutoScroll(baby.id, dayEntries);

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _BabyPicker(controller: controller),
          ),
          // day navigation (as in the Android app)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  tooltip: 'Previous day',
                  onPressed: () => _shiftDay(-1),
                ),
                Text(
                  _dayLabel,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  tooltip: 'Next day',
                  onPressed: () => _shiftDay(1),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              dayEntries.isEmpty
                  ? (_isToday
                      ? 'Nothing logged yet today.'
                      : 'Nothing logged this day.')
                  : '${dayEntries.length} entries · ${fmtDuration(totalMin)} of care${_isToday ? ' today' : ''}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: DayTimeline(
                dayStart: _dayStart,
                entries: dayEntries,
                caregiverById: repo.caregiverById,
                taskById: repo.taskById,
                scrollController: _scroll,
                onEditEntry: (e) => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LogEntryForm(baby: baby, existing: e),
                  ),
                ),
                onEmptyTap: (hour) => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LogEntryForm(
                      baby: baby,
                      initialStartMillis: _dayStart + hour * 3600000,
                      initialDurationMin: 60,
                    ),
                  ),
                ),
                onEntryChanged: (updated) async {
                  await repo.updateEntry(updated);
                  controller.refresh();
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Log care'),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => LogEntryForm(baby: baby)),
        ),
      ),
    );
  }
}

class _BabyPicker extends StatelessWidget {
  const _BabyPicker({required this.controller});
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
