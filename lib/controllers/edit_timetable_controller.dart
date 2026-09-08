import 'package:flutter/material.dart';

import '../constants/timetable_prompt.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../services/widget_data_service.dart';

class _EditHistoryState {
  final Map<String, dynamic> timetable;
  final int periodCount;

  _EditHistoryState(this.timetable, this.periodCount);
}

class EditTimetableController extends ChangeNotifier {
  Map<String, dynamic> _timetable;
  int _periodCount;
  final List<_EditHistoryState> _undoStack = [];
  final List<_EditHistoryState> _redoStack = [];
  bool _hasChanges = false;
  static const int _maxStackDepth = 50;

  EditTimetableController(Map<String, dynamic> initial, {int? periodCount})
      : _timetable = _deepCopyTimetable(initial),
        _periodCount = periodCount ??
            (calculateMaxPeriod(initial) > 9
                ? calculateMaxPeriod(initial)
                : 9);

  Map<String, dynamic> get timetable => _timetable;
  int get periodCount => _periodCount;
  List<int> get periods => List.generate(_periodCount, (i) => i + 1);
  bool get hasChanges => _hasChanges;
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  static int calculateMaxPeriod(Map<String, dynamic> timetable) {
    int maxP = 0;
    for (final val in timetable.values) {
      if (val is List) {
        for (final item in val) {
          if (item is Map && item['period'] != null) {
            final p = item['period'];
            final n = p is int ? p : int.tryParse(p.toString()) ?? 0;
            if (n > maxP) maxP = n;
          }
        }
      }
    }
    return maxP;
  }

  void _pushState() {
    _undoStack.add(
      _EditHistoryState(_deepCopyTimetable(_timetable), _periodCount),
    );
    if (_undoStack.length > _maxStackDepth) _undoStack.removeAt(0);
    _redoStack.clear();
    _hasChanges = true;
    notifyListeners();
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(
      _EditHistoryState(_deepCopyTimetable(_timetable), _periodCount),
    );
    final prev = _undoStack.removeLast();
    _timetable = prev.timetable;
    _periodCount = prev.periodCount;
    _hasChanges = _undoStack.isNotEmpty || _redoStack.isNotEmpty;
    notifyListeners();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(
      _EditHistoryState(_deepCopyTimetable(_timetable), _periodCount),
    );
    final next = _redoStack.removeLast();
    _timetable = next.timetable;
    _periodCount = next.periodCount;
    _hasChanges = true;
    notifyListeners();
  }

  List<Map<String, dynamic>> _getDayList(String dayKey) {
    final raw = _timetable[dayKey];
    if (raw is List) {
      return raw.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Map<String, dynamic>? getPeriod(String dayKey, int periodNumber) {
    final list = _getDayList(dayKey);
    for (final entry in list) {
      final p = entry['period'];
      final num = p is int ? p : int.tryParse(p.toString());
      if (num == periodNumber) return entry;
    }
    return null;
  }

  void createPeriod(String dayKey, int periodNumber, Map<String, dynamic> data) {
    _pushState();
    final list = _getDayList(dayKey);
    list.add({...data, 'period': periodNumber});
    _timetable[dayKey] = list;
    notifyListeners();
  }

  void editPeriod(String dayKey, int periodNumber, Map<String, dynamic> data) {
    _pushState();
    final list = _getDayList(dayKey);
    for (var i = 0; i < list.length; i++) {
      final p = list[i]['period'];
      final num = p is int ? p : int.tryParse(p.toString());
      if (num == periodNumber) {
        list[i] = {...data, 'period': periodNumber};
        break;
      }
    }
    _timetable[dayKey] = list;
    notifyListeners();
  }

  void deletePeriod(String dayKey, int periodNumber) {
    _pushState();
    final list = _getDayList(dayKey);
    list.removeWhere((entry) {
      final p = entry['period'];
      final num = p is int ? p : int.tryParse(p.toString());
      return num == periodNumber;
    });
    _timetable[dayKey] = list;
    notifyListeners();
  }

  void addPeriodColumn() {
    if (_periodCount >= 15) return;
    _pushState();
    _periodCount++;
    notifyListeners();
  }

  void removePeriodColumn(int periodNumber) {
    if (_periodCount <= 1) return;
    _pushState();
    for (final dayKey in kDayKeys) {
      final list = _getDayList(dayKey);
      list.removeWhere((entry) {
        final p = entry['period'];
        final num = p is int ? p : int.tryParse(p.toString());
        return num == periodNumber;
      });
      for (final entry in list) {
        final p = entry['period'];
        final num = p is int ? p : int.tryParse(p.toString()) ?? 0;
        if (num > periodNumber) {
          entry['period'] = num - 1;
        }
      }
      _timetable[dayKey] = list;
    }
    _periodCount--;
    notifyListeners();
  }

  void setPeriodCount(int count) {
    if (count == _periodCount || count < 1 || count > 15) return;
    _periodCount = count;
    notifyListeners();
  }

  void reorderPeriod(String dayKey, int fromPeriod, int toPeriod) {
    if (fromPeriod == toPeriod) return;
    _pushState();
    final list = _getDayList(dayKey);
    final fromIdx = list.indexWhere((e) {
      final p = e['period'];
      return (p is int ? p : int.tryParse(p.toString())) == fromPeriod;
    });
    if (fromIdx < 0) return;
    final item = list.removeAt(fromIdx);
    item['period'] = toPeriod;
    list.add(item);
    _timetable[dayKey] = list;
    notifyListeners();
  }

  Future<bool> save() async {
    if (!_hasChanges) return true;
    try {
      final data = {'teacher': '', 'timetable': _timetable};
      final existing = await StorageService.loadTimetable();
      if (existing != null) {
        data['teacher'] = existing['teacher']?.toString() ?? '';
      }
      await StorageService.saveTimetable(data);
      await StorageService.savePeriodCount(_periodCount);
      await NotificationService.scheduleAll(
        (data['timetable'] as Map).cast<String, dynamic>(),
      );
      await WidgetDataService.updateWidget();
      _hasChanges = false;
      _undoStack.clear();
      _redoStack.clear();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  static Map<String, dynamic> _deepCopyTimetable(Map<String, dynamic> src) {
    final copy = <String, dynamic>{};
    for (final entry in src.entries) {
      if (entry.value is List) {
        copy[entry.key] = (entry.value as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } else {
        copy[entry.key] = entry.value;
      }
    }
    return copy;
  }
}
