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

String fmtDuration(int minutes) {
  if (minutes < 60) return '${minutes}m';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

String fmtDate(DateTime dt) =>
    '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
