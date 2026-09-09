import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/spacing.dart';
import '../constants/timetable_prompt.dart';
import '../controllers/edit_timetable_controller.dart';
import '../services/storage_service.dart';
import '../theme/relational_colors.dart';
import '../widgets/app_feedback.dart';
import '../widgets/period_edit_sheet.dart';

class EditTimetableScreen extends StatefulWidget {
  final Map<String, dynamic> timetable;

  const EditTimetableScreen({super.key, required this.timetable});

  @override
  State<EditTimetableScreen> createState() => _EditTimetableScreenState();
}

class _EditTimetableScreenState extends State<EditTimetableScreen> {
  late final EditTimetableController _controller;

  @override
  void initState() {
    super.initState();
    _controller = EditTimetableController(widget.timetable);
    _controller.addListener(() => setState(() {}));
    _initPeriodCount();
  }

  Future<void> _initPeriodCount() async {
    final stored = await StorageService.loadPeriodCount();
    if (mounted && !_controller.hasChanges && stored != _controller.periodCount) {
      final maxP =
          EditTimetableController.calculateMaxPeriod(widget.timetable);
      final effective = stored > maxP ? stored : (maxP > 0 ? maxP : stored);
      _controller.setPeriodCount(effective);
    }
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
    final available = _controller.periods.where((p) => p != periodNumber).toList();
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
                    child: Text(
                      '$p',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: occupied
                            ? colors.borderMuted
                            : colors.action,
                      ),
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
      builder: (_) => PeriodEditSheet(
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
        AppFeedback.showError(context, 'Failed to save. Please try again.');
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
        ..._controller.periods.map((p) => SizedBox(
              width: 64,
              child: GestureDetector(
                onLongPress: () => _showRemoveColumnConfirmation(p),
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
              ),
            )),
        if (_controller.periodCount < 15)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                _controller.addPeriodColumn();
              },
              child: Container(
                width: 32,
                height: 28,
                decoration: BoxDecoration(
                  color: colors.action.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colors.action.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.add_rounded,
                  size: 16,
                  color: colors.action,
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showRemoveColumnConfirmation(int periodNumber) {
    if (_controller.periodCount <= 1) {
      AppFeedback.showError(context, 'Cannot remove the only period column.');
      return;
    }

    final colors = context.relColors;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Delete Period $periodNumber Column?',
          style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700),
        ),
        content: Text(
          'This will remove Period $periodNumber and all its scheduled classes across all days. Subsequent periods will be shifted down.',
          style: TextStyle(fontFamily: 'Inter', color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Inter')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              HapticFeedback.mediumImpact();
              _controller.removePeriodColumn(periodNumber);
            },
            style: TextButton.styleFrom(foregroundColor: colors.danger),
            child: const Text('Delete Column', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
          ),
        ],
      ),
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
          ..._controller.periods.map((p) => _buildCell(dayKey, p, colors)),
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
                painter: DashedBorderPainter(
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
        Text(
          'P$periodNum',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: colors.action,
          ),
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
