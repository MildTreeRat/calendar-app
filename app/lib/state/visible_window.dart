import 'package:flutter/foundation.dart';

/// Manages the visible time window for calendar views
class VisibleWindow extends ChangeNotifier {
  int _startMs;
  int _endMs;
  final int _prefetchThresholdDays = 7;

  VisibleWindow({
    int? startMs,
    int? endMs,
  })  : _startMs = startMs ?? _getDefaultStart(),
        _endMs = endMs ?? _getDefaultEnd();

  int get startMs => _startMs;
  int get endMs => _endMs;

  /// Initial window: now - 7 days to now + 60 days
  static int _getDefaultStart() {
    return DateTime.now()
        .subtract(const Duration(days: 7))
        .millisecondsSinceEpoch;
  }

  static int _getDefaultEnd() {
    return DateTime.now()
        .add(const Duration(days: 60))
        .millisecondsSinceEpoch;
  }

  /// Get window as DateTime objects
  DateTime get start => DateTime.fromMillisecondsSinceEpoch(_startMs);
  DateTime get end => DateTime.fromMillisecondsSinceEpoch(_endMs);

  /// Get window duration in days
  int get durationDays {
    return DateTime.fromMillisecondsSinceEpoch(_endMs)
        .difference(DateTime.fromMillisecondsSinceEpoch(_startMs))
        .inDays;
  }

  /// Check if a timestamp is near the start of the window
  bool isNearStart(int timestampMs) {
    final threshold = DateTime.fromMillisecondsSinceEpoch(_startMs)
        .add(Duration(days: _prefetchThresholdDays))
        .millisecondsSinceEpoch;
    return timestampMs <= threshold;
  }

  /// Check if a timestamp is near the end of the window
  bool isNearEnd(int timestampMs) {
    final threshold = DateTime.fromMillisecondsSinceEpoch(_endMs)
        .subtract(Duration(days: _prefetchThresholdDays))
        .millisecondsSinceEpoch;
    return timestampMs >= threshold;
  }

  /// Extend window backward (earlier dates)
  void extendBackward({int days = 14}) {
    final newStart = DateTime.fromMillisecondsSinceEpoch(_startMs)
        .subtract(Duration(days: days))
        .millisecondsSinceEpoch;

    _startMs = newStart;
    notifyListeners();
  }

  /// Extend window forward (later dates)
  void extendForward({int days = 14}) {
    final newEnd = DateTime.fromMillisecondsSinceEpoch(_endMs)
        .add(Duration(days: days))
        .millisecondsSinceEpoch;

    _endMs = newEnd;
    notifyListeners();
  }

  /// Set window to contain a specific date
  void ensureContains(DateTime date) {
    final dateMs = date.millisecondsSinceEpoch;
    var changed = false;

    if (dateMs < _startMs) {
      _startMs = date.subtract(const Duration(days: 7)).millisecondsSinceEpoch;
      changed = true;
    }

    if (dateMs > _endMs) {
      _endMs = date.add(const Duration(days: 60)).millisecondsSinceEpoch;
      changed = true;
    }

    if (changed) {
      notifyListeners();
    }
  }

  /// Reset to today's window
  void resetToToday() {
    _startMs = _getDefaultStart();
    _endMs = _getDefaultEnd();
    notifyListeners();
  }

  /// Check if window contains a date
  bool contains(DateTime date) {
    final dateMs = date.millisecondsSinceEpoch;
    return dateMs >= _startMs && dateMs <= _endMs;
  }
}
