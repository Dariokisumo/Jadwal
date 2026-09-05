import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:permission_handler/permission_handler.dart';

import '../constants/spacing.dart';
import '../constants/timetable_prompt.dart';
import '../constants/weekday_map.dart';
import '../models/period_model.dart';
import '../constants/app_version.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../services/update_service.dart';
import '../services/widget_data_service.dart';
import '../theme/relational_colors.dart';
import '../widgets/period_card.dart';
import '../widgets/theme_bottom_sheet.dart';
import '../widgets/update_dialog.dart';
import '../widgets/wavy_divider.dart';
import 'edit_timetable_screen.dart';
import 'setup_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _teacherName = '';
  Map<String, dynamic> _timetable = {};
  List<Period> _selectedDayPeriods = [];
  String _selectedDayKey = '';
  bool _loading = true;
  Timer? _refreshTimer;
  PeriodStatus? _previousActiveStatus;
  late PageController _pageController;
  bool _permissionsMissing = false;
  bool _exactAlarmMissing = false;
  bool _showFinishedOverride = false;
  final Map<String, Set<int>> _finishedOverridesByDay = {};

  Set<int> _overridesFor(String dayKey) =>
      _finishedOverridesByDay[dayKey] ?? {};


  static const List<String> _allDaysInOrder = [
    'saturday',
    'sunday',
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
  ];

  String get _todayKey => kWeekdayMap[DateTime.now().weekday] ?? '';

  bool get _isToday => _selectedDayKey == _todayKey;

  int get _dayIndex => _allDaysInOrder.indexOf(_selectedDayKey);

  Period? get _currentActivePeriod {
    if (!_isToday) return null;
    for (final p in _selectedDayPeriods) {
      if (p.status == PeriodStatus.active) return p;
    }
    return null;
  }

  List<Period> get _todayPeriods {
    final todayKey = _todayKey;
    final data = _timetable[todayKey] as List? ?? [];
    return data
        .map((e) => Period.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.periodNumber.compareTo(b.periodNumber));
  }

  String get _appBarSubtitle {
    final todayKey = _todayKey;
    if (todayKey == 'friday') return 'Rest Day';

    final todayPeriods = _todayPeriods;
    if (todayPeriods.isEmpty) return 'No periods today';

    Period? active;
    for (final p in todayPeriods) {
      if (p.status == PeriodStatus.active) {
        active = p;
        break;
      }
    }

    if (active != null) {
      return 'Period ${active.periodNumber} of ${todayPeriods.length} • ${active.subject}';
    }

    final finishedCount =
        todayPeriods.where((p) => p.status == PeriodStatus.finished).length;
    if (finishedCount == todayPeriods.length) return 'All done for today';

    final nextList = todayPeriods
        .where((p) => p.status == PeriodStatus.upcoming)
        .toList();
    if (nextList.isNotEmpty) {
      final n = nextList.first;
      final mins = n.minutesUntilStart;
      if (mins != null && mins > 0) {
        return 'Next: ${n.subject} in ${Period.formatMinutes(mins)}';
      }
      return 'Next: ${n.subject}';
    }

    return '${todayPeriods.length} periods today';
  }

  @override
  void initState() {
    super.initState();
    _selectedDayKey = _todayKey;
    final initialIndex = _allDaysInOrder.indexOf(_selectedDayKey);
    _pageController = PageController(
      initialPage: initialIndex >= 0 ? initialIndex : _dayIndex,
    );
    _loadTimetable();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkSilentUpdate();
    });
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        _detectPeriodTransition();
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _detectPeriodTransition() {
    if (!_isToday) return;
    final currentActive = _currentActivePeriod;
    final currentStatus = currentActive?.status;
    if (_previousActiveStatus != null &&
        _previousActiveStatus != currentStatus &&
        currentStatus == PeriodStatus.active) {
      HapticFeedback.lightImpact();
    }
    _previousActiveStatus = currentStatus;
  }

  Future<void> _loadTimetable() async {
    final data = await StorageService.loadTimetable();

    if (data == null) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SetupScreen()),
        );
      }
      return;
    }

    final teacher = data['teacher']?.toString() ?? '';
    final timetable = data['timetable'] as Map<String, dynamic>;

    setState(() {
      _teacherName = teacher;
      _timetable = timetable;
      _loading = false;
    });

    _loadPeriodsForDay(_selectedDayKey);
    _scheduleNotificationsForToday();
    _checkPermissions();
    _enforceNotificationPermission();

    // Update home screen widget
    try {
      await WidgetDataService.updateWidget();
    } catch (e, stack) {
      developer.log('Widget update failed', name: 'HomeScreen', error: e, stackTrace: stack);
    }
  }

  Future<void> _enforceNotificationPermission() async {
    final status = await Permission.notification.status;
    if (!status.isGranted && mounted) {
      _showMandatoryPermissionDialog();
    } else {
      // Check exact alarm permission too — request it to trigger system dialog
      final exactAlarmOk = await NotificationService.requestExactAlarmPermission();
      if (!exactAlarmOk && mounted) {
        _showExactAlarmPermissionDialog();
      }
    }
  }

  void _showMandatoryPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Notifications Required', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
        content: const Text(
          'Jadwal needs notification permissions to remind you about your classes. '
          'Please enable notifications in system settings to continue.',
          style: TextStyle(fontFamily: 'Inter'),
        ),
        actions: [
          TextButton(
            onPressed: () => openAppSettings(),
            child: const Text('Open Settings', style: TextStyle(fontFamily: 'Inter')),
          ),
          TextButton(
            onPressed: () async {
              final status = await Permission.notification.status;
              if (status.isGranted) {
                if (mounted) Navigator.pop(ctx);
                _scheduleNotificationsForToday();
                _checkPermissions();
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Permission still missing.')),
                  );
                }
              }
            },
            child: const Text('I\'ve Enabled It', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showExactAlarmPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Exact Alarm Permission', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
        content: const Text(
          'Jadwal needs "Alarms & reminders" permission to send notifications at the exact time before each class.\n\n'
          'Please enable "Alarms & reminders" in the settings screen, then come back and tap "I\'ve Enabled It".',
          style: TextStyle(fontFamily: 'Inter'),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (Platform.isAndroid) {
                const intent = AndroidIntent(
                  action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
                  data: 'package:com.example.jadwal',
                );
                await intent.launch();
              } else {
                await openAppSettings();
              }
            },
            child: const Text('Open Settings', style: TextStyle(fontFamily: 'Inter')),
          ),
          TextButton(
            onPressed: () async {
              final granted = await NotificationService.hasExactAlarmPermission();
              if (granted) {
                if (mounted) Navigator.pop(ctx);
                _scheduleNotificationsForToday();
                _checkPermissions();
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Permission still missing. Please enable "Alarms & reminders".')),
                  );
                }
              }
            },
            child: const Text('I\'ve Enabled It', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _checkPermissions() async {
    try {
      final ok = await NotificationService.arePermissionsGranted();
      final exactOk = await NotificationService.hasExactAlarmPermission();
      if (mounted) {
        setState(() {
          _permissionsMissing = !ok;
          _exactAlarmMissing = !exactOk;
        });
      }
    } catch (e, st) {
      developer.log('Permission check failed', name: 'HomeScreen', error: e, stackTrace: st);
    }
  }

  void _loadPeriodsForDay(String dayKey) {
    if (dayKey == 'friday') {
      setState(() => _selectedDayPeriods = []);
      return;
    }
    final dayList = (_timetable[dayKey] as List? ?? [])
        .map((e) => Period.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.periodNumber.compareTo(b.periodNumber));
    setState(() => _selectedDayPeriods = dayList);
    _loadOverrides(dayKey);
  }

  Future<void> _loadOverrides(String dayKey) async {
    final list = await StorageService.loadFinishedOverrides(dayKey);
    if (mounted) {
      setState(() => _finishedOverridesByDay[dayKey] = list.toSet());
    }
  }

  void _togglePeriodFinished(int periodNumber) {
    final next = Set<int>.from(_overridesFor(_selectedDayKey));
    if (next.contains(periodNumber)) {
      next.remove(periodNumber);
    } else {
      next.add(periodNumber);
    }
    setState(() => _finishedOverridesByDay[_selectedDayKey] = next);
    StorageService.saveFinishedOverrides(_selectedDayKey, next.toList());
  }

  bool _isPeriodManuallyFinished(int periodNumber, String dayKey) {
    return _overridesFor(dayKey).contains(periodNumber);
  }

  Future<void> _scheduleNotificationsForToday() async {
    try {
      await NotificationService.scheduleAll(_timetable);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notifications could not be scheduled. Open Settings > Jadwal > Notifications to verify permissions.'),
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _onDaySelected(String dayKey) {
    if (dayKey == _selectedDayKey) return;
    final newIndex = _allDaysInOrder.indexOf(dayKey);
    final currentIndex = _dayIndex;
    setState(() {
      _selectedDayKey = dayKey;
    });
    _loadPeriodsForDay(dayKey);
    if (newIndex >= 0) {
      final diff = (newIndex - currentIndex).abs();
      if (diff <= 1) {
        // Adjacent day — smooth slide feels natural.
        _pageController.animateToPage(
          newIndex,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        );
      } else {
        // Distant day — jump directly to avoid sliding through intermediates.
        _pageController.jumpToPage(newIndex);
      }
    }
  }

  void _onPageChanged(int index) {
    final dayKey = _allDaysInOrder[index];
    if (dayKey == _selectedDayKey) return;
    setState(() {
      _selectedDayKey = dayKey;
    });
    _loadPeriodsForDay(dayKey);
  }

  bool _isSameBlock(Period a, Period b) {
    final blockA = a.periodNumber <= 6 ? 0 : 1;
    final blockB = b.periodNumber <= 6 ? 0 : 1;
    return blockA == blockB;
  }

  Future<void> _reimport() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Re-import timetable?'),
        content: const Text(
          'This will replace your current timetable. You will need to '
          'paste or upload a new JSON file.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Replace'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await StorageService.clear();
      await NotificationService.cancelAll();
    } catch (e, st) {
      developer.log('Reimport cleanup failed', name: 'HomeScreen', error: e, stackTrace: st);
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const SetupScreen()),
    );
  }

  void _onMenuAction(String value) {
    switch (value) {
      case 'edit':
        _openEditor();
        break;
      case 'replace':
        _reimport();
        break;
      case 'theme':
        _showThemeSheet();
        break;
      case 'update':
        _checkManualUpdate();
        break;
    }
  }

  Future<void> _checkSilentUpdate() async {
    final release = await UpdateService.checkForUpdate(force: false);
    if (release != null && release.isNewer && mounted) {
      UpdateDialog.show(context, release);
    }
  }

  Future<void> _checkManualUpdate() async {
    final colors = context.relColors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Checking for updates...',
          style: TextStyle(fontFamily: 'Inter'),
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: colors.surfaceContainer,
      ),
    );

    final release = await UpdateService.checkForUpdate(force: true);
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (release != null && release.isNewer) {
      UpdateDialog.show(context, release);
    } else if (release != null && !release.isNewer) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Jadwal is up to date (v$kAppVersion)',
            style: const TextStyle(fontFamily: 'Inter'),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not reach GitHub. Check your internet connection.',
            style: TextStyle(fontFamily: 'Inter'),
          ),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _showThemeSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const ThemeBottomSheet(),
    );
  }

  Future<void> _openEditor() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditTimetableScreen(timetable: _timetable),
      ),
    );
    if (result == true && mounted) {
      _loadTimetable();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
    final colors = context.relColors;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: colors.action,
              ),
            ),
          ],
        ),
      ),
    );
    }

    final colors = context.relColors;

    final allFinished = _isToday &&
        _selectedDayPeriods.isNotEmpty &&
        _selectedDayPeriods.every((p) =>
            p.status == PeriodStatus.finished ||
            _overridesFor(_selectedDayKey).contains(p.periodNumber));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: colors.action,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _teacherName.isEmpty ? 'Today' : _teacherName,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              _appBarSubtitle,
              key: ValueKey(_appBarSubtitle),
              style: TextStyle(
                fontFamily: 'PlayfairDisplay',
                fontStyle: FontStyle.italic,
                fontSize: 12.5,
                color: colors.textSecondary,
              ),
            ).animate().fadeIn(duration: 200.ms),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: _onMenuAction,
            icon: Icon(
              Icons.more_vert_rounded,
              color: colors.textSecondary,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 3,
            color: colors.surface,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                child: _menuRow(
                  icon: Icons.edit_calendar_rounded,
                  label: 'Edit timetable',
                  colors: colors,
                ),
              ),
              PopupMenuItem(
                value: 'replace',
                child: _menuRow(
                  icon: Icons.upload_file_rounded,
                  label: 'Replace timetable',
                  colors: colors,
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'theme',
                child: _menuRow(
                  icon: Icons.palette_rounded,
                  label: 'Theme',
                  colors: colors,
                ),
              ),
              PopupMenuItem(
                value: 'update',
                child: _menuRow(
                  icon: Icons.system_update_alt_rounded,
                  label: 'Check for updates',
                  colors: colors,
                ),
              ),
            ],
          ),
          if (_permissionsMissing || _exactAlarmMissing)
            IconButton(
              icon: Icon(Icons.notifications_off_rounded, color: colors.danger),
              tooltip: _permissionsMissing ? 'Enable Notifications' : 'Fix Alarms & Reminders',
              onPressed: () async {
                if (_permissionsMissing) {
                  await openAppSettings();
                } else if (_exactAlarmMissing) {
                  await NotificationService.requestExactAlarmPermission();
                }
                _checkPermissions();
              },
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildDaySelector(colors),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: _buildDayContent(colors, allFinished),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDaySelector(RelationalColors colors) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colors.borderSubtle,
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: _allDaysInOrder.map((dayKey) {
          return _DayChip(
            dayKey: dayKey,
            label: kDayAbbreviations[dayKey] ?? dayKey.substring(0, 2),
            isSelected: dayKey == _selectedDayKey,
            isToday: dayKey == _todayKey,
            isFriday: dayKey == 'friday',
            onTap: () => _onDaySelected(dayKey),
            colors: colors,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDayContent(RelationalColors colors, bool allFinished) {
    return PageView.builder(
      controller: _pageController,
      onPageChanged: _onPageChanged,
      itemCount: _allDaysInOrder.length,
      itemBuilder: (context, index) {
        final dayKey = _allDaysInOrder[index];
        if (dayKey == 'friday') {
          return _restDayState(colors);
        }

        final dayPeriods = (_timetable[dayKey] as List? ?? [])
            .map((e) => Period.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.periodNumber.compareTo(b.periodNumber));

        if (dayPeriods.isEmpty) {
          return _emptyState(
            icon: Icons.event_busy_outlined,
            title: 'No classes',
            subtitle: 'No periods scheduled for ${kDayLabels[dayKey] ?? dayKey}.',
            colors: colors,
          );
        }

        final dayIsToday = dayKey == _todayKey;
        final dayAllFinished = dayIsToday &&
            !_showFinishedOverride &&
            dayPeriods.every((p) =>
                p.status == PeriodStatus.finished ||
                _overridesFor(dayKey).contains(p.periodNumber));

        if (dayAllFinished) {
          return _allDoneState(colors);
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.base,
            AppSpacing.md,
            AppSpacing.base,
            AppSpacing.xl,
          ),
          itemCount: dayPeriods.length,
          itemBuilder: (context, i) {
            return Column(
              children: [
                PeriodCard(
                  key: ValueKey('period-${dayPeriods[i].periodNumber}-${_overridesFor(dayKey)}'),
                  period: dayPeriods[i],
                  showStatus: dayIsToday && !_showFinishedOverride,
                  isVeryNext: dayIsToday &&
                      dayPeriods[i].status == PeriodStatus.upcoming &&
                      dayPeriods
                          .take(i)
                          .every((p) => p.status != PeriodStatus.upcoming),
                  isManuallyFinished: _isPeriodManuallyFinished(dayPeriods[i].periodNumber, dayKey),
                  onToggleFinished: dayIsToday
                      ? () => _togglePeriodFinished(dayPeriods[i].periodNumber)
                      : null,
                ),
                if (i < dayPeriods.length - 1)
                  _isSameBlock(dayPeriods[i], dayPeriods[i + 1])
                      ? const SizedBox(height: AppSpacing.sm)
                      : WavyDivider(
                          lineColor: colors.borderSubtle,
                          iconColor: colors.action,
                        ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _menuRow({
    required IconData icon,
    required String label,
    required RelationalColors colors,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: colors.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: colors.textPrimary,
            ),
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required RelationalColors colors,
    VoidCallback? onIconTap,
  }) {
    final iconWidget = Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: colors.actionSubtle,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 30, color: colors.action),
    );

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onIconTap != null)
              GestureDetector(
                onTap: onIconTap,
                child: iconWidget,
              )
            else
              iconWidget,
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13.5,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _restDayState(RelationalColors colors) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final cupIcon = Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: colors.actionSubtle,
        shape: BoxShape.circle,
        border: Border.all(
          color: colors.action.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Icon(
        Icons.coffee_rounded,
        size: 36,
        color: colors.action,
      ),
    );
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (reduceMotion)
              cupIcon
            else
              cupIcon
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(
                    begin: const Offset(1, 1),
                    end: const Offset(1.05, 1.05),
                    duration: 2000.ms,
                    curve: Curves.easeInOut,
                  )
                  .then(delay: 1000.ms),
            const SizedBox(height: 16),
            Text(
              'Rest Day',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "It's Friday — no classes scheduled. Enjoy your day off!",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13.5,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _allDoneState(RelationalColors colors) {
    return Column(
      children: [
        Expanded(
          child: _emptyState(
            icon: Icons.check_circle_outline,
            title: 'All done for today!',
            subtitle: "You've finished every period scheduled today.",
            colors: colors,
            onIconTap: () {
              HapticFeedback.lightImpact();
              setState(() => _showFinishedOverride = true);
            },
          ),
        ),
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  final String dayKey;
  final String label;
  final bool isSelected;
  final bool isToday;
  final bool isFriday;
  final VoidCallback onTap;
  final RelationalColors colors;

  const _DayChip({
    required this.dayKey,
    required this.label,
    required this.isSelected,
    required this.isToday,
    required this.isFriday,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = isFriday
        ? colors.actionSubtle
        : isSelected
            ? colors.action
            : isToday
                ? colors.surface
                : colors.surfaceContainerHighest;

    final textColor = isFriday
        ? colors.action.withValues(alpha: 0.6)
        : isSelected
            ? colors.onAction
            : colors.textPrimary;

    final borderColor = isFriday
        ? colors.action.withValues(alpha: 0.2)
        : isSelected
            ? colors.action
            : isToday
                ? colors.action
                : colors.borderSubtle;

    final dayLabel = kDayLabels[dayKey] ?? dayKey;
    final semanticsLabel = isFriday
        ? '$dayLabel, no classes'
        : '$dayLabel${isToday ? ', today' : ''}${isSelected ? ', selected' : ''}';

    return Semantics(
      label: semanticsLabel,
      button: true,
      enabled: !isFriday,
      selected: isSelected,
      child: GestureDetector(
        onTap: isFriday ? null : onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: chipColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: borderColor,
                  width: isSelected || isToday ? 1.5 : 1,
                ),
              ),
              alignment: Alignment.center,
              child: isFriday
                  ? Icon(
                      Icons.coffee_rounded,
                      size: 16,
                      color: textColor,
                    )
                  : Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: textColor,
                      ),
                    ),
            ),
            const SizedBox(height: 4),
            if (isToday)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: CustomPaint(
                  size: const Size(8, 5),
                  painter: _TrianglePainter(color: colors.action),
                ),
              )
            else
              const SizedBox(height: 7),
          ],
        ),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;

  const _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter old) => old.color != color;
}

