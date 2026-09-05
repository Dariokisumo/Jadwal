import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../constants/period_schedule.dart';
import '../constants/period_visuals.dart';
import '../constants/spacing.dart';
import '../constants/timetable_prompt.dart';
import '../services/storage_service.dart';
import '../theme/relational_colors.dart';

class EditTimetableController extends ChangeNotifier {
  Map<String, dynamic> _timetable;
  final List<Map<String, dynamic>> _undoStack = [];
  final List<Map<String, dynamic>> _redoStack = [];
  bool _hasChanges = false;
  static const int _maxStackDepth = 50;

  EditTimetableController(Map<String, dynamic> initial)
      : _timetable = _deepCopyTimetable(initial);

  Map<String, dynamic> get timetable => _timetable;
  bool get hasChanges => _hasChanges;
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  void _pushState() {
    _undoStack.add(_deepCopyTimetable(_timetable));
    if (_undoStack.length > _maxStackDepth) _undoStack.removeAt(0);
    _redoStack.clear();
    _hasChanges = true;
    notifyListeners();
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_deepCopyTimetable(_timetable));
    _timetable = _undoStack.removeLast();
    _hasChanges = _undoStack.isNotEmpty || _redoStack.isNotEmpty;
    notifyListeners();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_deepCopyTimetable(_timetable));
    _timetable = _redoStack.removeLast();
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

class EditTimetableScreen extends StatefulWidget {
  final Map<String, dynamic> timetable;

  const EditTimetableScreen({super.key, required this.timetable});

  @override
  State<EditTimetableScreen> createState() => _EditTimetableScreenState();
}

class _EditTimetableScreenState extends State<EditTimetableScreen> {
  late final EditTimetableController _controller;
  static const List<int> _periods = [1, 2, 3, 4, 5, 6, 7, 8, 9];

  @override
  void initState() {
    super.initState();
    _controller = EditTimetableController(widget.timetable);
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onCellTap(String dayKey, int periodNumber) {
    final existing = _controller.getPeriod(dayKey, periodNumber);
    HapticFeedback.lightImpact();
    _showPeriodEditSheet(dayKey, periodNumber, existing);
  }

  void _onCellLongPress(String dayKey, int periodNumber) {
    final existing = _controller.getPeriod(dayKey, periodNumber);
    if (existing == null) return;
    HapticFeedback.mediumImpact();
    _showReorderSheet(dayKey, periodNumber);
  }

  void _showReorderSheet(String dayKey, int periodNumber) {
    final available = _periods.where((p) => p != periodNumber).toList();
    final colors = context.relColors;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
        ),
        padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.md, AppSpacing.base, AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Move Period $periodNumber to...',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: available.map((p) {
                final occupied = _controller.getPeriod(dayKey, p) != null;
                return GestureDetector(
                  onTap: occupied
                      ? null
                      : () {
                          Navigator.pop(ctx);
                          _controller.reorderPeriod(dayKey, periodNumber, p);
                        },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: occupied
                          ? colors.surfaceContainerHighest
                          : colors.actionSubtle,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: occupied
                            ? colors.borderSubtle
                            : colors.action.withValues(alpha: 0.3),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      PeriodVisuals.icons[p] ?? Icons.circle,
                      size: 22,
                      color: occupied
                          ? colors.borderMuted
                          : colors.action,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _showPeriodEditSheet(String dayKey, int periodNumber, Map<String, dynamic>? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PeriodEditSheet(
        dayKey: dayKey,
        periodNumber: periodNumber,
        existing: existing,
        onSave: (data) {
          if (existing != null) {
            _controller.editPeriod(dayKey, periodNumber, data);
          } else {
            _controller.createPeriod(dayKey, periodNumber, data);
          }
        },
        onDelete: existing != null
            ? () {
                _showDeleteConfirmation(dayKey, periodNumber);
              }
            : null,
      ),
    );
  }

  void _showDeleteConfirmation(String dayKey, int periodNumber) {
    final colors = context.relColors;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Delete Period?',
          style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700),
        ),
        content: Text(
          'This will remove Period $periodNumber from ${kDayLabels[dayKey] ?? dayKey}.',
          style: const TextStyle(fontFamily: 'Inter'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Inter')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(ctx);
              _controller.deletePeriod(dayKey, periodNumber);
            },
            style: TextButton.styleFrom(foregroundColor: colors.danger),
            child: const Text('Delete', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final ok = await _controller.save();
    if (mounted) {
      if (ok) {
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.relColors;

    return PopScope(
      canPop: !_controller.hasChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _showUnsavedChangesDialog();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: colors.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: colors.textPrimary),
            onPressed: () {
              if (_controller.hasChanges) {
                _showUnsavedChangesDialog();
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
          title: Text(
            'Edit Timetable',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(
                Icons.undo_rounded,
                color: _controller.canUndo ? colors.textPrimary : colors.borderMuted,
              ),
              onPressed: _controller.canUndo ? _controller.undo : null,
              tooltip: 'Undo',
            ),
            IconButton(
              icon: Icon(
                Icons.redo_rounded,
                color: _controller.canRedo ? colors.textPrimary : colors.borderMuted,
              ),
              onPressed: _controller.canRedo ? _controller.redo : null,
              tooltip: 'Redo',
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            Expanded(child: _buildGrid(colors)),
            _buildBottomBar(colors),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(RelationalColors colors) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: Column(
            children: [
              _buildPeriodHeaders(colors),
              const SizedBox(height: AppSpacing.sm),
              ...kDayKeys.map((dayKey) => _buildDayRow(dayKey, colors)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodHeaders(RelationalColors colors) {
    return Row(
      children: [
        const SizedBox(width: 44),
        ..._periods.map((p) => SizedBox(
              width: 64,
              child: Center(
                child: Text(
                  'P$p',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildDayRow(String dayKey, RelationalColors colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              kDayAbbreviations[dayKey] ?? dayKey.substring(0, 2),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
          ),
          ..._periods.map((p) => _buildCell(dayKey, p, colors)),
        ],
      ),
    );
  }

  Widget _buildCell(String dayKey, int periodNumber, RelationalColors colors) {
    final periodData = _controller.getPeriod(dayKey, periodNumber);
    final isEmpty = periodData == null;

    return GestureDetector(
      onTap: () => _onCellTap(dayKey, periodNumber),
      onLongPress: () => _onCellLongPress(dayKey, periodNumber),
      child: Container(
        width: 64,
        height: 48,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isEmpty
              ? colors.surfaceContainerHighest
              : colors.actionSubtle,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isEmpty
                ? colors.borderSubtle
                : colors.action.withValues(alpha: 0.35),
            width: isEmpty ? 1 : 1.5,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: isEmpty
            ? CustomPaint(
                painter: _DashedBorderPainter(
                  color: colors.borderSubtle,
                ),
                child: Center(
                  child: Icon(
                    Icons.add_rounded,
                    size: 16,
                    color: colors.borderMuted,
                  ),
                ),
              )
            : _buildFilledCell(periodData, colors),
      ),
    );
  }

  Widget _buildFilledCell(Map<String, dynamic> data, RelationalColors colors) {
    final subject = data['subject']?.toString() ?? '';
    final classroom = data['classroom']?.toString() ?? '';
    final periodNum = data['period'] is int
        ? data['period'] as int
        : int.tryParse(data['period'].toString()) ?? 1;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          PeriodVisuals.icons[periodNum] ?? Icons.circle,
          size: 14,
          color: colors.action,
        ),
        const SizedBox(height: 2),
        Text(
          subject,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        Text(
          classroom,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 8,
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(RelationalColors colors) {
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.sm, AppSpacing.base, AppSpacing.base),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(
            color: colors.borderSubtle,
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            onPressed: _controller.hasChanges ? _save : null,
            style: FilledButton.styleFrom(
              backgroundColor: colors.action,
              foregroundColor: colors.onAction,
              disabledBackgroundColor: colors.surfaceContainerHighest,
              disabledForegroundColor: colors.borderMuted,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Save',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showUnsavedChangesDialog() {
    final colors = context.relColors;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Unsaved Changes',
          style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'You have unsaved changes. Do you want to discard them?',
          style: TextStyle(fontFamily: 'Inter'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep Editing', style: TextStyle(fontFamily: 'Inter')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(foregroundColor: colors.danger),
            child: const Text('Discard', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _PeriodEditSheet extends StatefulWidget {
  final String dayKey;
  final int periodNumber;
  final Map<String, dynamic>? existing;
  final ValueChanged<Map<String, dynamic>> onSave;
  final VoidCallback? onDelete;

  const _PeriodEditSheet({
    required this.dayKey,
    required this.periodNumber,
    required this.existing,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<_PeriodEditSheet> createState() => _PeriodEditSheetState();
}

class _PeriodEditSheetState extends State<_PeriodEditSheet> {
  late final TextEditingController _subjectController;
  String? _selectedClass;
  late String _startTime;
  late String _endTime;
  String? _subjectError;
  String? _classroomError;
  String? _timeError;

  @override
  void initState() {
    super.initState();
    _subjectController = TextEditingController(text: widget.existing?['subject']?.toString() ?? '');

    final existingClass = widget.existing?['classroom']?.toString();
    if (existingClass != null && kClassOptions.contains(existingClass)) {
      _selectedClass = existingClass;
    }

    if (widget.existing != null) {
      _startTime = widget.existing!['start']?.toString() ?? '8:00 AM';
      _endTime = widget.existing!['end']?.toString() ?? '8:40 AM';
    } else {
      final schedule = kPeriodSchedule[widget.periodNumber];
      _startTime = schedule?[0] ?? '8:00 AM';
      _endTime = schedule?[1] ?? '8:40 AM';
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    super.dispose();
  }

  bool _validate() {
    bool valid = true;
    setState(() {
      _subjectError = null;
      _classroomError = null;
      _timeError = null;
    });

    if (_subjectController.text.trim().isEmpty) {
      setState(() => _subjectError = 'Subject is required');
      valid = false;
    }
    if (_selectedClass == null) {
      setState(() => _classroomError = 'Class is required');
      valid = false;
    }

    final timePattern = RegExp(r'^\d{1,2}:\d{2}\s(AM|PM)$');
    if (!timePattern.hasMatch(_startTime)) {
      setState(() => _timeError = 'Invalid start time format');
      valid = false;
    }
    if (!timePattern.hasMatch(_endTime)) {
      setState(() => _timeError = 'Invalid end time format');
      valid = false;
    }

    if (valid) {
      try {
        final format = DateFormat('h:mm a');
        final s = format.parse(_startTime);
        final e = format.parse(_endTime);
        if (!s.isBefore(e)) {
          setState(() => _timeError = 'Start time must be before end time');
          valid = false;
        }
      } catch (_) {
        setState(() => _timeError = 'Invalid time format');
        valid = false;
      }
    }

    return valid;
  }

  void _save() {
    if (!_validate()) return;
    widget.onSave({
      'subject': _subjectController.text.trim().toUpperCase(),
      'classroom': _selectedClass!,
      'start': _startTime,
      'end': _endTime,
    });
    Navigator.of(context).pop();
  }

  Future<void> _pickTime({required bool isStart}) async {
    final current = isStart ? _startTime : _endTime;
    final timePattern = RegExp(r'^(\d{1,2}):(\d{2})\s(AM|PM)$');
    final match = timePattern.firstMatch(current);

    TimeOfDay initial;
    if (match != null) {
      var hour = int.parse(match.group(1)!);
      final minute = int.parse(match.group(2)!);
      final period = match.group(3);
      if (period == 'PM' && hour != 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;
      initial = TimeOfDay(hour: hour, minute: minute);
    } else {
      initial = isStart ? const TimeOfDay(hour: 8, minute: 0) : const TimeOfDay(hour: 8, minute: 40);
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final hour = picked.hourOfPeriod == 0 ? 12 : picked.hourOfPeriod;
      final minute = picked.minute.toString().padLeft(2, '0');
      final period = picked.period == DayPeriod.am ? 'AM' : 'PM';
      final formatted = '$hour:$minute $period';
      setState(() {
        if (isStart) {
          _startTime = formatted;
        } else {
          _endTime = formatted;
        }
        _timeError = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.relColors;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
        ),
        padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.md, AppSpacing.base, AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Period ${widget.periodNumber} — ${kDayLabels[widget.dayKey] ?? widget.dayKey}',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                if (widget.onDelete != null)
                  IconButton(
                    icon: Icon(Icons.delete_outline_rounded, color: colors.danger, size: 22),
                    onPressed: widget.onDelete,
                    tooltip: 'Delete period',
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _buildTextField(
              controller: _subjectController,
              label: 'Subject',
              hint: 'e.g. HAD',
              error: _subjectError,
              textCapitalization: TextCapitalization.characters,
              colors: colors,
              onChanged: (_) => setState(() => _subjectError = null),
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildClassDropdown(colors: colors),
            const SizedBox(height: AppSpacing.sm),
            if (_timeError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(
                  _timeError!,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: colors.danger,
                  ),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: _buildTimeButton(
                    label: 'Start',
                    time: _startTime,
                    onTap: () => _pickTime(isStart: true),
                    colors: colors,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _buildTimeButton(
                    label: 'End',
                    time: _endTime,
                    onTap: () => _pickTime(isStart: false),
                    colors: colors,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.action,
                  foregroundColor: colors.onAction,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Save',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? error,
    TextCapitalization textCapitalization = TextCapitalization.none,
    required RelationalColors colors,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          textCapitalization: textCapitalization,
          onChanged: onChanged,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            color: colors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              color: colors.borderMuted,
            ),
            errorText: error,
            errorStyle: const TextStyle(fontFamily: 'Inter', fontSize: 12),
            filled: true,
            fillColor: colors.surfaceContainer,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: colors.borderSubtle),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: colors.borderSubtle),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: colors.action, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildClassDropdown({required RelationalColors colors}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Class',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          initialValue: _selectedClass,
          isExpanded: true,
          dropdownColor: colors.surfaceContainer,
          borderRadius: BorderRadius.circular(10),
          icon: Icon(Icons.unfold_more_rounded, size: 18, color: colors.textSecondary),
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            color: colors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: 'Select class',
            hintStyle: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              color: colors.borderMuted,
            ),
            errorText: _classroomError,
            errorStyle: const TextStyle(fontFamily: 'Inter', fontSize: 12),
            filled: true,
            fillColor: colors.surfaceContainer,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: colors.borderSubtle),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: colors.borderSubtle),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: colors.action, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          items: kClassOptions.map((cls) {
            return DropdownMenuItem<String>(
              value: cls,
              child: Text(cls),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedClass = value;
              _classroomError = null;
            });
          },
        ),
      ],
    );
  }

  Widget _buildTimeButton({
    required String label,
    required String time,
    required VoidCallback onTap,
    required RelationalColors colors,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: colors.surfaceContainer,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.borderSubtle),
            ),
            child: Row(
              children: [
                Icon(Icons.access_time_rounded, size: 18, color: colors.textSecondary),
                const SizedBox(width: 8),
                Text(
                  time,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;

  _DashedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const dashWidth = 4.0;
    const dashSpace = 3.0;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(8),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics().first;
    var distance = 0.0;

    while (distance < metrics.length) {
      final start = metrics.getTangentForOffset(distance)!.position;
      final end = distance + dashWidth < metrics.length
          ? metrics.getTangentForOffset(distance + dashWidth)!.position
          : metrics.getTangentForOffset(metrics.length)!.position;
      canvas.drawLine(start, end, paint);
      distance += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
