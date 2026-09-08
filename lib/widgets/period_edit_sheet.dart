import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../constants/period_schedule.dart';
import '../constants/spacing.dart';
import '../constants/timetable_prompt.dart';
import '../theme/relational_colors.dart';

class PeriodEditSheet extends StatefulWidget {
  final String dayKey;
  final int periodNumber;
  final Map<String, dynamic>? existing;
  final ValueChanged<Map<String, dynamic>> onSave;
  final VoidCallback? onDelete;

  const PeriodEditSheet({
    super.key,
    required this.dayKey,
    required this.periodNumber,
    required this.existing,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<PeriodEditSheet> createState() => _PeriodEditSheetState();
}

class _PeriodEditSheetState extends State<PeriodEditSheet> {
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
      final defaultTimes = defaultTimingForPeriod(widget.periodNumber);
      _startTime = defaultTimes[0];
      _endTime = defaultTimes[1];
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            decoration: BoxDecoration(
              color: colors.surfaceContainer,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.borderSubtle),
            ),
            child: Row(
              children: [
                Icon(Icons.access_time_rounded, size: 16, color: colors.textSecondary),
                const SizedBox(width: 6),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      time,
                      maxLines: 1,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14.5,
                        color: colors.textPrimary,
                      ),
                    ),
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

class DashedBorderPainter extends CustomPainter {
  final Color color;

  const DashedBorderPainter({required this.color});

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
