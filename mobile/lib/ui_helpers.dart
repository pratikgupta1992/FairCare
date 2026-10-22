/// Small shared UI helpers.
library;

import 'package:flutter/material.dart';

Color colorFromInt(int argb) => Color(argb);

String fmtTime(DateTime dt) {
  final h = dt.hour;
  final suffix = h >= 12 ? 'PM' : 'AM';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:${dt.minute.toString().padLeft(2, '0')} $suffix';
}

String _hourMinute(DateTime dt) {
  final h12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  return '$h12:${dt.minute.toString().padLeft(2, '0')}';
}

/// "7 AM" style hour label for the timeline gutter.
String fmtHour(DateTime dt) {
  final suffix = dt.hour >= 12 ? 'PM' : 'AM';
  final h12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  return '$h12 $suffix';
}

/// Compact range: "7:00–7:15 PM" — AM/PM shown once when both
/// ends share it and fall on the same day (port of the Kotlin
/// `fmtRange` in TodayScreen.kt).
String fmtRange(DateTime start, DateTime end) {
  final sameDay = start.year == end.year &&
      start.month == end.month &&
      start.day == end.day;
  final sameMeridiem = (start.hour >= 12) == (end.hour >= 12);
  return (sameDay && sameMeridiem)
      ? '${_hourMinute(start)}–${fmtTime(end)}'
      : '${fmtTime(start)}–${fmtTime(end)}';
}

String fmtDuration(int minutes) {
  if (minutes < 60) return '${minutes}m';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

String fmtDate(DateTime dt) =>
    '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
