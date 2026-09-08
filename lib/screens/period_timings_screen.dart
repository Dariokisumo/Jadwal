import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../constants/period_schedule.dart';
import '../constants/spacing.dart';
import '../models/timing_profile.dart';
import '../services/deep_link_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../services/widget_data_service.dart';
import '../theme/relational_colors.dart';
import '../widgets/period_slot_card.dart';
import '../widgets/profile_import_dialog.dart';

class PeriodTimingsScreen extends StatefulWidget {
  const PeriodTimingsScreen({super.key});

  @override
  State<PeriodTimingsScreen> createState() => _PeriodTimingsScreenState();
}

class _PeriodTimingsScreenState extends State<PeriodTimingsScreen> {
  bool _loading = true;
  List<TimingProfile> _profiles = [];
  int _selectedProfileIndex = 0;
  int _periodCount = 9;
  String? _activeAppliedProfileId;
  bool _timetableModified = false;
  bool _hasUnsavedProfileChanges = false;
  StreamSubscription<TimingProfile>? _deepLinkSub;

  TimingProfile get _currentProfile => _profiles[_selectedProfileIndex];

  @override
  void initState() {
    super.initState();
    _loadData();
    _deepLinkSub = DeepLinkService.onProfileReceived.listen((profile) {
      if (mounted) {
        _processIncomingProfile(profile);
      }
    });
  }

  @override
  void dispose() {
    _deepLinkSub?.cancel();
    super.dispose();
  }

  Future<void> _shareCurrentProfile() async {
    HapticFeedback.lightImpact();
    await TimingProfile.share(_currentProfile);
  }

  Future<void> _showImportDialog({String? initialText}) async {
    final colors = context.relColors;
    final controller = TextEditingController(text: initialText ?? '');

    // If initial text is empty, check clipboard
    if (controller.text.isEmpty) {
      final clip = await Clipboard.getData('text/plain');
      if (clip != null && clip.text != null && clip.text!.trim().isNotEmpty) {
        final text = clip.text!.trim();
        if (text.contains('jadwal://') ||
            text.contains('JADWAL_PROFILE:') ||
            text.contains('http://') ||
            text.contains('https://') ||
            text.startsWith('Sl') ||
            text.startsWith('{')) {
          controller.text = text;
        }
      }
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Import Timing Profile',
          style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Paste a shared Jadwal timing profile link or import code below:',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller,
              maxLines: 3,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: colors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'jadwal://profile?data=... or JADWAL_PROFILE:...',
                hintStyle: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: colors.borderMuted,
                ),
                filled: true,
                fillColor: colors.surfaceContainer,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: colors.borderSubtle),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              foregroundColor: colors.textSecondary,
              minimumSize: const Size(64, 44),
            ),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Inter')),
          ),
          FilledButton(
            onPressed: () {
              final raw = controller.text.trim();
              Navigator.pop(ctx);
              if (raw.isNotEmpty) {
                _processIncomingPayload(raw);
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: colors.action,
              foregroundColor: colors.onAction,
              minimumSize: const Size(90, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Inspect', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _processIncomingProfile(TimingProfile profile) async {
    if (!mounted) return;

    final confirmed = await ProfileImportDialog.show(context, profile: profile);
    if (confirmed == true && mounted) {
      final imported = await StorageService.importTimingProfile(profile);
      setState(() {
        _profiles.add(imported);
        _selectedProfileIndex = _profiles.length - 1;
        _hasUnsavedProfileChanges = true;
      });

      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Added "${imported.name}" to saved profiles!',
            style: const TextStyle(fontFamily: 'Inter'),
          ),
          backgroundColor: context.relColors.surfaceContainer,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _processIncomingPayload(String payload) async {
    final profile = TimingProfile.fromSharePayload(payload);
    if (profile == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Could not parse timing profile from link or code.',
              style: TextStyle(fontFamily: 'Inter'),
            ),
            backgroundColor: context.relColors.danger,
          ),
        );
      }
      return;
    }
    await _processIncomingProfile(profile);
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final count = await StorageService.loadPeriodCount();
    final timetable = await StorageService.loadTimetable();
    final profiles = await StorageService.loadTimingProfiles(
      periodCount: count,
      timetable: timetable,
    );
    final activeId = await StorageService.loadActiveProfileId();

    var activeIdx = 0;
    if (activeId != null) {
      final found = profiles.indexWhere((p) => p.id == activeId);
      if (found >= 0) activeIdx = found;
    }

    if (mounted) {
      setState(() {
        _periodCount = count;
        _profiles = profiles;
        _selectedProfileIndex = activeIdx;
        _activeAppliedProfileId = activeId ?? profiles.first.id;
        _loading = false;
        _hasUnsavedProfileChanges = false;
      });
    }
  }

  Future<void> _saveProfiles() async {
    await StorageService.saveTimingProfiles(_profiles);
    if (mounted) {
      setState(() {
        _hasUnsavedProfileChanges = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Saved profile "${_currentProfile.name}"',
            style: const TextStyle(fontFamily: 'Inter'),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _applyToTimetable() async {
    final colors = context.relColors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Apply "${_currentProfile.name}"?',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'This will update start and end times for all matching period slots across Saturday–Thursday in your active timetable.',
          style: TextStyle(
            fontFamily: 'Inter',
            color: colors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Inter')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: colors.action,
              foregroundColor: colors.onAction,
            ),
            child: const Text(
              'Apply Now',
              style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Load timetable
    final timetableData = await StorageService.loadTimetable();
    if (timetableData == null || timetableData['timetable'] is! Map) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No timetable found to update.')),
        );
      }
      return;
    }

    final rawDays = timetableData['timetable'] as Map;
    final updatedDays = <String, dynamic>{};

    for (final entry in rawDays.entries) {
      final dayKey = entry.key;
      final periodList = entry.value;
      if (periodList is List) {
        final updatedList = <Map<String, dynamic>>[];
        for (final item in periodList) {
          if (item is Map) {
            final periodMap = Map<String, dynamic>.from(item);
            final pNum = periodMap['period'] is int
                ? periodMap['period'] as int
                : int.tryParse(periodMap['period'].toString());

            if (pNum != null) {
              final times = _currentProfile.getTimingFor(pNum);
              periodMap['start'] = times[0];
              periodMap['end'] = times[1];
            }
            updatedList.add(periodMap);
          }
        }
        updatedDays[dayKey] = updatedList;
      } else {
        updatedDays[dayKey] = periodList;
      }
    }

    timetableData['timetable'] = updatedDays;

    await StorageService.saveTimetable(timetableData);
    await StorageService.saveActiveProfileId(_currentProfile.id);
    await StorageService.saveTimingProfiles(_profiles);

    // Run notifications & widget update asynchronously in background for instant UI response
    unawaited(NotificationService.scheduleAll(updatedDays));
    unawaited(WidgetDataService.updateWidget());

    if (mounted) {
      setState(() {
        _activeAppliedProfileId = _currentProfile.id;
        _timetableModified = true;
        _hasUnsavedProfileChanges = false;
      });

      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Timetable updated with "${_currentProfile.name}" timings!',
            style: const TextStyle(fontFamily: 'Inter'),
          ),
          backgroundColor: colors.surfaceContainer,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _createNewProfile() {
    final colors = context.relColors;
    final nameController = TextEditingController(
      text: 'Schedule ${_profiles.length + 1}',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'New Timing Profile',
          style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Give your timing profile a recognizable name (e.g. "Winter Timings", "Exam Schedule").',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              style: TextStyle(fontFamily: 'Inter', color: colors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Profile Name',
                filled: true,
                fillColor: colors.surfaceContainer,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: colors.borderSubtle),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Inter')),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              _addProfile(name);
            },
            style: FilledButton.styleFrom(
              backgroundColor: colors.action,
              foregroundColor: colors.onAction,
            ),
            child: const Text('Create', style: TextStyle(fontFamily: 'Inter')),
          ),
        ],
      ),
    );
  }

  void _addProfile(String name) {
    // Clone slots from current profile or defaults
    final newSlots = <int, List<String>>{};
    for (var i = 1; i <= _periodCount; i++) {
      newSlots[i] = _currentProfile.getTimingFor(i);
    }

    final newProfile = TimingProfile(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      slots: newSlots,
    );

    setState(() {
      _profiles.add(newProfile);
      _selectedProfileIndex = _profiles.length - 1;
      _hasUnsavedProfileChanges = true;
    });

    _saveProfiles();
  }

  void _renameCurrentProfile() {
    final colors = context.relColors;
    final nameController = TextEditingController(text: _currentProfile.name);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Rename Profile',
          style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: nameController,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          style: TextStyle(fontFamily: 'Inter', color: colors.textPrimary),
          decoration: InputDecoration(
            labelText: 'Profile Name',
            filled: true,
            fillColor: colors.surfaceContainer,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: colors.borderSubtle),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Inter')),
          ),
          FilledButton(
            onPressed: () {
              final newName = nameController.text.trim();
              if (newName.isEmpty) return;
              Navigator.pop(ctx);
              setState(() {
                _currentProfile.name = newName;
                _hasUnsavedProfileChanges = true;
              });
              _saveProfiles();
            },
            style: FilledButton.styleFrom(
              backgroundColor: colors.action,
              foregroundColor: colors.onAction,
            ),
            child: const Text('Save', style: TextStyle(fontFamily: 'Inter')),
          ),
        ],
      ),
    );
  }

  void _deleteCurrentProfile() {
    if (_profiles.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete the only profile.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final colors = context.relColors;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Delete "${_currentProfile.name}"?',
          style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'This timing profile will be removed. Timetable periods currently using these timings will remain unaffected.',
          style: TextStyle(fontFamily: 'Inter'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Inter')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              final removedId = _currentProfile.id;
              setState(() {
                _profiles.removeAt(_selectedProfileIndex);
                if (_selectedProfileIndex >= _profiles.length) {
                  _selectedProfileIndex = _profiles.length - 1;
                }
                if (_activeAppliedProfileId == removedId) {
                  _activeAppliedProfileId = _profiles[_selectedProfileIndex].id;
                }
                _hasUnsavedProfileChanges = true;
              });
              _saveProfiles();
            },
            style: TextButton.styleFrom(foregroundColor: colors.danger),
            child: const Text('Delete', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _duplicateCurrentProfile() {
    final duplicate = _currentProfile.copyWith(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: '${_currentProfile.name} (Copy)',
    );

    setState(() {
      _profiles.add(duplicate);
      _selectedProfileIndex = _profiles.length - 1;
      _hasUnsavedProfileChanges = true;
    });

    _saveProfiles();
  }

  Future<void> _pickTimeForPeriod({
    required int periodNumber,
    required bool isStart,
  }) async {
    final currentTimes = _currentProfile.getTimingFor(periodNumber);
    final currentStr = isStart ? currentTimes[0] : currentTimes[1];

    final timePattern = RegExp(r'^(\d{1,2}):(\d{2})\s(AM|PM)$');
    final match = timePattern.firstMatch(currentStr.trim());

    TimeOfDay initial;
    if (match != null) {
      var hour = int.parse(match.group(1)!);
      final minute = int.parse(match.group(2)!);
      final period = match.group(3);
      if (period == 'PM' && hour != 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;
      initial = TimeOfDay(hour: hour, minute: minute);
    } else {
      initial = isStart
          ? const TimeOfDay(hour: 8, minute: 0)
          : const TimeOfDay(hour: 8, minute: 40);
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
        final existing = _currentProfile.getTimingFor(periodNumber);
        if (isStart) {
          _currentProfile.slots[periodNumber] = [formatted, existing[1]];
        } else {
          _currentProfile.slots[periodNumber] = [existing[0], formatted];
        }
        _hasUnsavedProfileChanges = true;
      });

      // Auto-save changes to profile in background
      StorageService.saveTimingProfiles(_profiles);
    }
  }

  void _addPeriodSlot() {
    if (_periodCount >= 15) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 15 periods supported.')),
      );
      return;
    }

    setState(() {
      _periodCount++;
      for (final prof in _profiles) {
        if (!prof.slots.containsKey(_periodCount)) {
          prof.slots[_periodCount] = defaultTimingForPeriod(_periodCount);
        }
      }
      _hasUnsavedProfileChanges = true;
    });

    StorageService.savePeriodCount(_periodCount);
    StorageService.saveTimingProfiles(_profiles);
  }

  void _removeLastPeriodSlot() {
    if (_periodCount <= 1) return;

    final colors = context.relColors;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Remove Period $_periodCount?',
          style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700),
        ),
        content: Text(
          'This will decrease the configured periods from $_periodCount to ${_periodCount - 1}.',
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
              setState(() {
                for (final prof in _profiles) {
                  prof.slots.remove(_periodCount);
                }
                _periodCount--;
                _hasUnsavedProfileChanges = true;
              });
              StorageService.savePeriodCount(_periodCount);
              StorageService.saveTimingProfiles(_profiles);
            },
            style: TextButton.styleFrom(foregroundColor: colors.danger),
            child: const Text('Remove', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.relColors;

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
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: colors.textPrimary),
            onPressed: () => Navigator.of(context).pop(_timetableModified),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Period Timings',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              Text(
                'Schedule profiles & bulk times',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.file_download_outlined, color: colors.action),
              tooltip: 'Import Profile',
              onPressed: () => _showImportDialog(),
            ),
            IconButton(
              icon: Icon(Icons.add_rounded, color: colors.action),
              tooltip: 'New Profile',
              onPressed: _createNewProfile,
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _buildProfileSelector(colors),
                  _buildProfileActionsBar(colors),
                  Expanded(
                    child: _buildSlotsList(colors),
                  ),
                  _buildBottomBar(colors),
                ],
              ),
      ),
    );
  }

  Widget _buildProfileSelector(RelationalColors colors) {
    return Container(
      color: colors.surface,
      padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.sm, AppSpacing.base, AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'PROFILES',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: colors.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                '${_profiles.length} saved',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ..._profiles.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final prof = entry.value;
                  final isSelected = idx == _selectedProfileIndex;
                  final isApplied = prof.id == _activeAppliedProfileId;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() {
                          _selectedProfileIndex = idx;
                        });
                      },
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isApplied) ...[
                            Icon(
                              Icons.check_circle_rounded,
                              size: 14,
                              color: isSelected ? colors.onAction : colors.action,
                            ),
                            const SizedBox(width: 5),
                          ],
                          Text(
                            prof.name,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 13,
                              color: isSelected ? colors.onAction : colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      selectedColor: colors.action,
                      backgroundColor: colors.surfaceContainer,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: isSelected
                              ? colors.action
                              : (isApplied ? colors.action.withValues(alpha: 0.4) : colors.borderSubtle),
                          width: isSelected || isApplied ? 1.5 : 1,
                        ),
                      ),
                      showCheckmark: false,
                    ),
                  );
                }),
                // Add New Profile Chip
                ActionChip(
                  onPressed: _createNewProfile,
                  avatar: Icon(Icons.add_rounded, size: 16, color: colors.action),
                  label: Text(
                    'Add New',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.action,
                    ),
                  ),
                  backgroundColor: colors.action.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: colors.action.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Import Profile Chip
                ActionChip(
                  onPressed: () => _showImportDialog(),
                  avatar: Icon(Icons.file_download_outlined, size: 16, color: colors.action),
                  label: Text(
                    'Import',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.action,
                    ),
                  ),
                  backgroundColor: colors.action.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: colors.action.withValues(alpha: 0.3),
                      width: 1,
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

  Widget _buildProfileActionsBar(RelationalColors colors) {
    final isApplied = _currentProfile.id == _activeAppliedProfileId;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          bottom: BorderSide(
            color: colors.borderSubtle,
            width: 0.5,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: 6),
      child: Row(
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isApplied
                    ? colors.action.withValues(alpha: 0.12)
                    : colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                isApplied ? '✓ In use in timetable' : 'Saved profile',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isApplied ? colors.action : colors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.share_rounded, size: 18, color: colors.action),
            tooltip: 'Share Profile',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: _shareCurrentProfile,
          ),
          IconButton(
            icon: Icon(Icons.edit_outlined, size: 18, color: colors.textSecondary),
            tooltip: 'Rename',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: _renameCurrentProfile,
          ),
          IconButton(
            icon: Icon(Icons.copy_rounded, size: 17, color: colors.textSecondary),
            tooltip: 'Duplicate',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: _duplicateCurrentProfile,
          ),
          if (_profiles.length > 1)
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, size: 18, color: colors.danger),
              tooltip: 'Delete Profile',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: _deleteCurrentProfile,
            ),
        ],
      ),
    );
  }

  Widget _buildSlotsList(RelationalColors colors) {
    final slots = <Widget>[];

    for (var i = 1; i <= _periodCount; i++) {
      final pNum = i;
      final times = _currentProfile.getTimingFor(pNum);
      final startTime = times[0];
      final endTime = times[1];

      // Calculate break from previous period if i > 1
      if (i > 1) {
        final prevTimes = _currentProfile.getTimingFor(i - 1);
        final gap = _calculateGapMinutes(prevTimes[1], startTime);
        if (gap != null && gap > 0) {
          slots.add(BreakIndicatorRow(gapMinutes: gap, colors: colors));
        }
      }

      slots.add(PeriodSlotCard(
        periodNumber: pNum,
        startTime: startTime,
        endTime: endTime,
        onStartTap: () => _pickTimeForPeriod(periodNumber: pNum, isStart: true),
        onEndTap: () => _pickTimeForPeriod(periodNumber: pNum, isStart: false),
        colors: colors,
      ));
    }

    // Add Period Slot Control Buttons at bottom of list
    slots.add(
      Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.base),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            OutlinedButton.icon(
              onPressed: _addPeriodSlot,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text('Add Period ${_periodCount + 1}'),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.action,
                side: BorderSide(color: colors.action.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            if (_periodCount > 1)
              TextButton.icon(
                onPressed: _removeLastPeriodSlot,
                icon: Icon(Icons.remove_rounded, size: 18, color: colors.danger),
                label: Text(
                  'Remove Period $_periodCount',
                  style: TextStyle(color: colors.danger, fontFamily: 'Inter'),
                ),
              ),
          ],
        ),
      ),
    );

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.base),
      children: slots,
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
        child: Row(
          children: [
            if (_hasUnsavedProfileChanges)
              Expanded(
                flex: 2,
                child: OutlinedButton(
                  onPressed: _saveProfiles,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.textPrimary,
                    side: BorderSide(color: colors.borderSubtle),
                    minimumSize: const Size.fromHeight(48),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Save Profile',
                      maxLines: 1,
                      style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            if (_hasUnsavedProfileChanges) const SizedBox(width: AppSpacing.sm),
            Expanded(
              flex: 3,
              child: FilledButton.icon(
                onPressed: _applyToTimetable,
                icon: const Icon(Icons.sync_rounded, size: 18),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Apply to Timetable',
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: colors.action,
                  foregroundColor: colors.onAction,
                  minimumSize: const Size.fromHeight(48),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int? _calculateGapMinutes(String endStr, String nextStartStr) {
    try {
      final format = DateFormat('h:mm a');
      final prevEnd = format.parse(endStr.trim());
      final nextStart = format.parse(nextStartStr.trim());
      final diff = nextStart.difference(prevEnd).inMinutes;
      return diff;
    } catch (_) {
      return null;
    }
  }
}
