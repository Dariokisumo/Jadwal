import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';

import '../constants/spacing.dart';
import '../models/saved_timetable.dart';
import '../services/deep_link_service.dart';
import '../services/json_validator.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../services/widget_data_service.dart';
import '../theme/relational_colors.dart';
import '../widgets/app_feedback.dart';

class SavedTimetablesScreen extends StatefulWidget {
  const SavedTimetablesScreen({super.key});

  @override
  State<SavedTimetablesScreen> createState() => _SavedTimetablesScreenState();
}

class _SavedTimetablesScreenState extends State<SavedTimetablesScreen> {
  bool _loading = true;
  List<SavedTimetable> _timetables = [];
  String? _activeId;
  bool _timetableModified = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final list = await StorageService.loadSavedTimetables();
    final activeId = await StorageService.loadActiveTimetableId();

    if (mounted) {
      setState(() {
        _timetables = list;
        _activeId = activeId ?? (list.isNotEmpty ? list.first.id : null);
        _loading = false;
      });
    }
  }

  SavedTimetable? get _activeTimetable {
    if (_timetables.isEmpty) return null;
    return _timetables.firstWhere(
      (t) => t.id == _activeId,
      orElse: () => _timetables.first,
    );
  }

  Future<void> _activate(SavedTimetable timetable) async {
    if (timetable.id == _activeId) return;
    HapticFeedback.mediumImpact();

    await StorageService.activateTimetable(timetable);
    try {
      await NotificationService.scheduleAll(timetable.data);
      await WidgetDataService.updateWidget();
    } catch (_) {}

    setState(() {
      _activeId = timetable.id;
      _timetableModified = true;
    });

    if (mounted) {
      AppFeedback.showSuccess(
        context,
        'Activated "${timetable.name}" schedule',
      );
    }
  }

  Future<void> _showSaveCurrentDialog() async {
    final colors = context.relColors;
    final current = await StorageService.loadTimetable();
    if (current == null) {
      if (mounted) {
        AppFeedback.showError(context, 'No active timetable found to save.');
      }
      return;
    }

    final teacher = current['teacher'] as String? ?? 'Teacher';
    final controller = TextEditingController(text: '$teacher Schedule');

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Save Current Timetable',
          style: TextStyle(fontFamily: 'Geist', fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Save a snapshot of your live schedule to your library:',
              style: TextStyle(fontFamily: 'Geist', fontSize: 13, color: colors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller,
              autofocus: true,
              style: TextStyle(fontFamily: 'Geist', fontSize: 14, color: colors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Schedule Name',
                hintText: 'e.g. Term 1, Exam Week',
                filled: true,
                fillColor: colors.surfaceContainer,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
          ),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);

              final newEntry = SavedTimetable(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: name,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                data: current,
              );

              _timetables.insert(0, newEntry);
              await StorageService.saveSavedTimetables(_timetables);
              setState(() => _timetableModified = true);

              if (mounted) {
                AppFeedback.showSuccess(context, 'Saved "$name" to library');
              }
            },
            style: FilledButton.styleFrom(backgroundColor: colors.action),
            child: const Text('Save to Library'),
          ),
        ],
      ),
    );
  }

  Future<void> _rename(SavedTimetable timetable) async {
    final colors = context.relColors;
    final controller = TextEditingController(text: timetable.name);

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Rename Timetable',
          style: TextStyle(fontFamily: 'Geist', fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(fontFamily: 'Geist', fontSize: 14, color: colors.textPrimary),
          decoration: InputDecoration(
            labelText: 'Schedule Name',
            filled: true,
            fillColor: colors.surfaceContainer,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            style: FilledButton.styleFrom(backgroundColor: colors.action),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != timetable.name) {
      final updated = timetable.copyWith(name: newName, updatedAt: DateTime.now());
      final index = _timetables.indexWhere((t) => t.id == timetable.id);
      if (index != -1) {
        _timetables[index] = updated;
        await StorageService.saveSavedTimetables(_timetables);
        setState(() {});
        if (mounted) {
          AppFeedback.showSuccess(context, 'Renamed to "$newName"');
        }
      }
    }
  }

  Future<void> _duplicate(SavedTimetable timetable) async {
    final dup = SavedTimetable(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: '${timetable.name} (Copy)',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      data: timetable.data,
    );

    _timetables.insert(0, dup);
    await StorageService.saveSavedTimetables(_timetables);
    setState(() {});
    if (mounted) {
      AppFeedback.showSuccess(context, 'Duplicated "${timetable.name}"');
    }
  }

  Future<void> _delete(SavedTimetable timetable) async {
    if (timetable.id == _activeId && _timetables.length > 1) {
      AppFeedback.showError(context, 'Cannot delete the active timetable. Activate another first.');
      return;
    }

    final colors = context.relColors;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Timetable?',
          style: TextStyle(fontFamily: 'Geist', fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Are you sure you want to delete "${timetable.name}"? This action cannot be undone.',
          style: TextStyle(fontFamily: 'Geist', fontSize: 13.5, color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: colors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      HapticFeedback.mediumImpact();
      _timetables.removeWhere((t) => t.id == timetable.id);
      await StorageService.saveSavedTimetables(_timetables);
      setState(() {});
      if (mounted) {
        AppFeedback.showSuccess(context, 'Deleted "${timetable.name}"');
      }
    }
  }

  Future<void> _directShareOrExport(SavedTimetable timetable) async {
    final rawSanitized = timetable.name.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final sanitizedName = rawSanitized.replaceAll('_', '').isEmpty ? 'Jadwal' : rawSanitized;
    final fileName = '${sanitizedName}_Timetable.jadwal';
    final fileContent = timetable.toFileContent();

    HapticFeedback.lightImpact();
    final success = await DeepLinkService.shareTimetableFile(
      fileName: fileName,
      content: fileContent,
      title: 'Share "${timetable.name}"',
    );
    if (!success && mounted) {
      AppFeedback.showError(context, 'Unable to open system share sheet');
    }
  }

  Future<void> _showExportOptions(SavedTimetable timetable) async {
    final colors = context.relColors;
    final rawSanitized = timetable.name.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final sanitizedName = rawSanitized.replaceAll('_', '').isEmpty ? 'Jadwal' : rawSanitized;
    final fileName = '${sanitizedName}_Timetable.jadwal';
    final fileContent = timetable.toFileContent();

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              const SizedBox(height: AppSpacing.base),
              Text(
                'Export "$fileName"',
                style: TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Option 1: Direct Share Sheet
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colors.actionSubtle,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.share_rounded, color: colors.action, size: 20),
                ),
                title: Text(
                  'Share File…',
                  style: TextStyle(fontFamily: 'Geist', fontWeight: FontWeight.w600, color: colors.textPrimary),
                ),
                subtitle: Text(
                  'Send via WhatsApp, Drive, Bluetooth, or Email',
                  style: TextStyle(fontFamily: 'Geist', fontSize: 12, color: colors.textSecondary),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final success = await DeepLinkService.shareTimetableFile(
                    fileName: fileName,
                    content: fileContent,
                    title: 'Share "${timetable.name}"',
                  );
                  if (!success && mounted) {
                    AppFeedback.showError(context, 'Unable to open system share sheet');
                  }
                },
              ),
              const SizedBox(height: AppSpacing.sm),

              // Option 2: Save to Downloads
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colors.actionSubtle,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.download_rounded, color: colors.action, size: 20),
                ),
                title: Text(
                  'Save to Downloads Folder',
                  style: TextStyle(fontFamily: 'Geist', fontWeight: FontWeight.w600, color: colors.textPrimary),
                ),
                subtitle: Text(
                  'Download directly into public storage',
                  style: TextStyle(fontFamily: 'Geist', fontSize: 12, color: colors.textSecondary),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final path = await DeepLinkService.saveTimetableFileToDownloads(
                    fileName: fileName,
                    content: fileContent,
                  );
                  if (path != null && mounted) {
                    AppFeedback.showSuccess(context, 'Saved to Downloads folder: $fileName');
                  } else if (mounted) {
                    AppFeedback.showError(context, 'Could not save file to Downloads.');
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndImportFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jadwal', 'json'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final fileBytes = result.files.single.bytes;
      if (fileBytes == null) {
        if (mounted) AppFeedback.showError(context, 'Could not read selected file.');
        return;
      }

      final rawString = utf8.decode(fileBytes);
      final normalized = JsonValidator.tryParseAndNormalize(rawString);

      if (normalized == null) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: context.relColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text(
                'Invalid Timetable File',
                style: TextStyle(fontFamily: 'Geist', fontWeight: FontWeight.w700),
              ),
              content: Text(
                'The selected file does not contain a valid timetable structure.\n\nPlease choose an exported .jadwal or .json file.',
                style: TextStyle(fontFamily: 'Geist', fontSize: 13.5, color: context.relColors.textSecondary),
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: FilledButton.styleFrom(backgroundColor: context.relColors.action),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return;
      }

      final fileName = result.files.single.name.replaceAll(RegExp(r'\.(jadwal|json)$', caseSensitive: false), '');
      final candidateName = fileName.replaceAll('_', ' ');

      final newTimetable = SavedTimetable(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: candidateName.isNotEmpty ? candidateName : '${normalized['teacher']} Timetable',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        data: normalized,
      );

      _timetables.insert(0, newTimetable);
      await StorageService.saveSavedTimetables(_timetables);
      setState(() {});

      if (mounted) {
        AppFeedback.showSuccess(context, 'Imported "${newTimetable.name}" to library!');
      }
    } catch (e) {
      if (mounted) AppFeedback.showError(context, 'Error importing file: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.relColors;

    // Separate active and inactive timetables for a single, unified list
    final activeItem = _activeTimetable;
    final inactiveItems = _timetables.where((t) => t.id != _activeId).toList();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pop(_timetableModified);
      },
      child: Scaffold(
        backgroundColor: colors.surface,
        appBar: AppBar(
          backgroundColor: colors.surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: colors.textPrimary),
            onPressed: () => Navigator.of(context).pop(_timetableModified),
          ),
          title: Text(
            'Saved Timetables',
            style: TextStyle(
              fontFamily: 'Geist',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.base),
                children: [
                  // Action Buttons Toolbar
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: _pickAndImportFile,
                          icon: const Icon(Icons.file_open_rounded, size: 18),
                          label: const Text(
                            'Import File',
                            style: TextStyle(fontFamily: 'Geist', fontSize: 13.5, fontWeight: FontWeight.w600),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: colors.actionSubtle,
                            foregroundColor: colors.action,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _showSaveCurrentDialog,
                          icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                          label: const Text(
                            'Save Current',
                            style: TextStyle(fontFamily: 'Geist', fontSize: 13.5, fontWeight: FontWeight.w600),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.textPrimary,
                            side: BorderSide(color: colors.borderSubtle),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Library Section Header
                  Text(
                    'SCHEDULE LIBRARY (${_timetables.length})',
                    style: TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Single Unified List (No duplicate hero card!)
                  if (_timetables.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.surfaceContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_month_outlined, size: 36, color: colors.textSecondary),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'No saved timetables yet.',
                            style: TextStyle(fontFamily: 'Geist', fontSize: 14, color: colors.textSecondary),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    // Pinned Active Item at the top
                    if (activeItem != null)
                      _buildScheduleCard(
                        timetable: activeItem,
                        isActive: true,
                        colors: colors,
                      ),
                    // Inactive Items
                    for (final item in inactiveItems)
                      _buildScheduleCard(
                        timetable: item,
                        isActive: false,
                        colors: colors,
                      ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildScheduleCard({
    required SavedTimetable timetable,
    required bool isActive,
    required RelationalColors colors,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive ? colors.action.withValues(alpha: 0.4) : colors.borderSubtle,
          width: isActive ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isActive ? colors.actionSubtle : colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isActive ? Icons.check_circle_rounded : Icons.calendar_today_rounded,
                  size: 18,
                  color: isActive ? colors.action : colors.textSecondary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            timetable.name,
                            style: TextStyle(
                              fontFamily: 'Geist',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isActive) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: colors.action,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'ACTIVE',
                              style: TextStyle(
                                fontFamily: 'Geist',
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: colors.onAction,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Teacher: ${timetable.teacher}',
                      style: TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 12.5,
                        color: colors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Direct 1-tap Share/Export Action Button
              IconButton(
                icon: const Icon(Icons.share_outlined, size: 20),
                color: colors.action,
                tooltip: 'Share / Export',
                padding: const EdgeInsets.all(12),
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                onPressed: () => _directShareOrExport(timetable),
              ),
              // Context Options Menu
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, size: 20, color: colors.textSecondary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: colors.surface,
                padding: const EdgeInsets.all(12),
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                onSelected: (action) {
                  if (action == 'activate') _activate(timetable);
                  if (action == 'export_options') _showExportOptions(timetable);
                  if (action == 'rename') _rename(timetable);
                  if (action == 'duplicate') _duplicate(timetable);
                  if (action == 'delete') _delete(timetable);
                },
                itemBuilder: (ctx) => [
                  if (!isActive)
                    const PopupMenuItem(
                      value: 'activate',
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline_rounded, size: 18),
                          SizedBox(width: 10),
                          Text('Activate Schedule'),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'export_options',
                    child: Row(
                      children: [
                        Icon(Icons.download_rounded, size: 18),
                        SizedBox(width: 10),
                        Text('Export Options (Save/Share)'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'rename',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18),
                        SizedBox(width: 10),
                        Text('Rename'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'duplicate',
                    child: Row(
                      children: [
                        Icon(Icons.copy_rounded, size: 18),
                        SizedBox(width: 10),
                        Text('Duplicate'),
                      ],
                    ),
                  ),
                  if (!isActive)
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 18, color: colors.danger),
                          SizedBox(width: 10),
                          Text('Delete', style: TextStyle(color: colors.danger)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Timetable Metadata Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.borderSubtle),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${timetable.totalClasses} classes • ${timetable.activeDays.length} days (${timetable.activeDays.join(', ')})',
                    style: TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: colors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (timetable.timeSpan != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    timetable.timeSpan!,
                    style: TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 11.5,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!isActive) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: () => _activate(timetable),
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text('Activate This Schedule'),
                style: FilledButton.styleFrom(
                  backgroundColor: colors.actionSubtle,
                  foregroundColor: colors.action,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
