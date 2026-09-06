import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';

import '../constants/spacing.dart';
import '../constants/timetable_prompt.dart';
import '../services/json_validator.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../theme/relational_colors.dart';
import '../widgets/wavy_progress_bar.dart';
import 'home_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> with SingleTickerProviderStateMixin {
  final _jsonController = TextEditingController();
  final _scrollController = ScrollController();
  bool _hasPastedContent = false;
  bool _promptCopied = false;
  bool _stepOneComplete = false;
  bool _showStepTwo = false;
  bool _showStepThree = false;
  bool _isProcessing = false;
  String? _errorMessage;
  bool _notificationsEnabled = false;
  bool _alarmsEnabled = false;

  static const _reducedMotionThreshold = 0;

  late final AnimationController _copyBounceController;
  late final AnimationController _activeDotPulseController;

  Duration _duration(int ms) {
    final reduced = MediaQuery.of(context).disableAnimations;
    return Duration(milliseconds: reduced ? _reducedMotionThreshold : ms);
  }

  late final Animation<double> _copyBounceScale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.95), weight: 25),
    TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.07), weight: 35),
    TweenSequenceItem(tween: Tween(begin: 1.07, end: 1.0), weight: 40),
  ]).animate(CurvedAnimation(parent: _copyBounceController, curve: Curves.easeOut));

  late final Animation<double> _activeDotPulseScale = Tween<double>(begin: 1.0, end: 1.2).animate(
    CurvedAnimation(parent: _activeDotPulseController, curve: Curves.easeInOut),
  );

  @override
  void initState() {
    super.initState();
    _copyBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _activeDotPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _activeDotPulseController.repeat(reverse: true);
    _jsonController.addListener(() {
      final hasContent = _jsonController.text.trim().isNotEmpty;
      if (hasContent != _hasPastedContent) {
        setState(() => _hasPastedContent = hasContent);
      }
      if (_errorMessage != null) {
        setState(() => _errorMessage = null);
      }
    });
  }

  @override
  void dispose() {
    _copyBounceController.dispose();
    _activeDotPulseController.dispose();
    _jsonController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _copyPrompt() async {
    if (_promptCopied) return;
    await Clipboard.setData(const ClipboardData(text: kTimetablePrompt));
    setState(() {
      _promptCopied = true;
      _stepOneComplete = true;
      _showStepTwo = true;
    });
    _copyBounceController.forward(from: 0.0);
    _scrollToStepTwo();
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _promptCopied = false);
  }

  void _scrollToStepTwo() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text != null && text.trim().isNotEmpty) {
      _jsonController.text = text.trim();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Pasted timetable JSON from clipboard',
              style: TextStyle(fontFamily: 'Inter'),
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Clipboard is empty or does not contain text',
            style: TextStyle(fontFamily: 'Inter'),
          ),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  static String _sanitizeJson(String raw) {
    var s = raw.trim();
    // Strip markdown code block fences if present: ```json ... ``` or ``` ... ```
    if (s.startsWith('```')) {
      final firstNewline = s.indexOf('\n');
      if (firstNewline != -1) {
        s = s.substring(firstNewline + 1);
      }
      if (s.endsWith('```')) {
        s = s.substring(0, s.length - 3);
      }
      s = s.trim();
    }
    // Extract outermost JSON object if surrounded by chat or explanation text
    final start = s.indexOf('{');
    final end = s.lastIndexOf('}');
    if (start != -1 && end != -1 && end > start) {
      s = s.substring(start, end + 1);
    }
    return s;
  }

  Future<void> _importJsonString(String raw) async {
    setState(() {
      _errorMessage = null;
      _isProcessing = true;
    });

    try {
      final cleaned = _sanitizeJson(raw);
      dynamic decoded;
      try {
        decoded = jsonDecode(cleaned);
      } catch (_) {
        setState(() {
          _errorMessage =
              'This is not valid JSON. Make sure the AI returned '
              'a valid timetable JSON object.';
          _isProcessing = false;
        });
        return;
      }

      final validation = JsonValidator.validate(decoded);
      if (!validation.isValid) {
        setState(() {
          _errorMessage = validation.errorMessage;
          _isProcessing = false;
        });
        return;
      }

      await StorageService.saveTimetable(validation.data!);

      try {
        await NotificationService.init();
        final notifGranted = await NotificationService.arePermissionsGranted();
        final alarmGranted = await NotificationService.hasExactAlarmPermission();

        if (notifGranted && alarmGranted) {
          if (!mounted) return;
          _navigateToHome();
          return;
        }

        if (mounted) {
          setState(() {
            _notificationsEnabled = notifGranted;
            _alarmsEnabled = alarmGranted;
            _isProcessing = false;
            _showStepThree = true;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _showStepThree = true;
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Something went wrong while importing: $e';
        _isProcessing = false;
      });
    }
  }

  void _navigateToHome() {
    final reduced = MediaQuery.of(context).disableAnimations;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: Duration(milliseconds: reduced ? 0 : 400),
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionsBuilder: (_, animation, __, child) {
          final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
          final scale = Tween(begin: 0.97, end: 1.0).animate(fade);
          return FadeTransition(
            opacity: fade,
            child: ScaleTransition(scale: scale, child: child),
          );
        },
      ),
    );
  }

  Future<void> _pickAndImportJson() async {
    setState(() {
      _errorMessage = null;
      _isProcessing = true;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _isProcessing = false);
        return;
      }

      final fileName = result.files.single.name;
      if (!fileName.toLowerCase().endsWith('.json')) {
        setState(() {
          _errorMessage = 'Please select a .json file.';
          _isProcessing = false;
        });
        return;
      }

      final fileBytes = result.files.single.bytes;
      if (fileBytes == null) {
        setState(() {
          _errorMessage = 'Could not read the selected file. Please try again.';
          _isProcessing = false;
        });
        return;
      }

      final rawString = utf8.decode(fileBytes);
      await _importJsonString(rawString);
    } catch (e) {
      setState(() {
        _errorMessage = 'Something went wrong while importing: $e';
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.relColors;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.lg),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.actionSubtle,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.schedule_rounded,
                  color: colors.action,
                  size: 26,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Jadwal',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: colors.action,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Turn a photo of your timetable into a live class tracker \u2014 no internet needed',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              _buildProgressIndicator(colors),
              const SizedBox(height: 24),
              if (!_showStepThree) ...[
                _buildStepOne(colors),
                if (_showStepTwo) ...[
                  const SizedBox(height: 20),
                  _buildStepTwo(colors),
                ],
              ] else ...[
                _buildCompletedSummary(colors),
                const SizedBox(height: 20),
                _buildStepThree(colors),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompletedSummary(RelationalColors colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: colors.actionSubtle,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.check_rounded,
              color: colors.action,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Timetable Imported',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Your schedule data is saved offline on device.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(RelationalColors colors) {
    final step = _showStepThree ? 3 : (_showStepTwo ? 2 : 1);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Row(
      children: [
        _progressDot(step >= 1, colors, pulse: step == 1),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: WavyProgressBar(
              value: step >= 2 ? 1.0 : 0.0,
              activeColor: colors.action,
              trackColor: colors.borderSubtle,
              height: 6.0,
              amplitude: 2.2,
              wavelength: 22.0,
              strokeWidth: 2.0,
              animate: !reduceMotion,
              valueDuration: const Duration(milliseconds: 500),
            ),
          ),
        ),
        _progressDot(step >= 2, colors, pulse: step == 2),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: WavyProgressBar(
              value: step >= 3 ? 1.0 : 0.0,
              activeColor: colors.action,
              trackColor: colors.borderSubtle,
              height: 6.0,
              amplitude: 2.2,
              wavelength: 22.0,
              strokeWidth: 2.0,
              animate: !reduceMotion,
              valueDuration: const Duration(milliseconds: 500),
            ),
          ),
        ),
        _progressDot(step >= 3, colors, pulse: step == 3),
        const SizedBox(width: 8),
        Text(
          'Step $step of 3',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _progressDot(bool active, RelationalColors colors, {bool pulse = false}) {
    final anim = (active && pulse) ? _activeDotPulseScale : null;
    return AnimatedBuilder(
      animation: anim ?? _activeDotPulseScale,
      builder: (context, child) {
        final scale = (active && pulse) ? _activeDotPulseScale.value : 1.0;
        return Transform.scale(scale: scale, child: child);
      },
      child: AnimatedContainer(
        duration: _duration(250),
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: active ? colors.action : colors.borderSubtle,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _buildStepOne(RelationalColors colors) {
    return _stepCard(
      stepNumber: '1',
      title: 'Generate your timetable data',
      body: 'Copy the prompt below, open an AI with reasoning capabilities '
          '(Claude, ChatGPT, Gemini, DeepSeek, etc.), attach a photo of your '
          'timetable, and paste the prompt. Models that show their reasoning '
          'produce the most reliable JSON output.',
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedBuilder(
            animation: _copyBounceScale,
            builder: (context, child) => Transform.scale(
              scale: _copyBounceScale.value,
              child: child,
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _copyPrompt,
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                  child: Icon(
                    _promptCopied ? Icons.check : Icons.copy_rounded,
                    key: ValueKey(_promptCopied),
                    size: 18,
                  ),
                ),
                label: Text(_promptCopied ? 'Prompt copied!' : 'Copy Prompt'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.action,
                  foregroundColor: colors.onAction,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ),
          if (_stepOneComplete)
            Semantics(
              label: _promptCopied ? 'Prompt copied' : 'Step one complete',
              liveRegion: true,
              child: const SizedBox.shrink(),
            ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Once the AI replies with JSON, copy the response and paste it '
            'in Step 2 below.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12.5,
              color: colors.textSecondary,
            ),
          ),
          if (!_showStepTwo) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  setState(() => _showStepTwo = true);
                  _scrollToStepTwo();
                },
                icon: Icon(Icons.arrow_downward_rounded, size: 16, color: colors.action),
                label: Text(
                  'Already have JSON? Paste it here →',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: colors.action,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStepTwo(RelationalColors colors) {
    return _stepCard(
      stepNumber: '2',
      title: 'Import your timetable',
      body: 'Paste the JSON the AI gave you, or upload a .json file.',
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Paste JSON',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              TextButton.icon(
                onPressed: _isProcessing ? null : _pasteFromClipboard,
                icon: Icon(Icons.content_paste_rounded, size: 14, color: colors.action),
                label: Text(
                  'Paste from clipboard',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.action,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _jsonController,
            maxLines: 8,
            minLines: 5,
            enabled: !_isProcessing,
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 12.5,
              color: colors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: '{\n  "teacher": "Dr. Smith",\n  "timetable": {\n    "saturday": [\n      {"period": 1, "subject": "ENG",\n       "classroom": "CL 6",\n       "start": "8:00 AM", "end": "8:40 AM"}\n    ]\n  }\n}',
              hintStyle: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12.5,
                color: colors.borderMuted,
              ),
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
                borderSide: BorderSide(color: colors.action, width: 2),
              ),
              contentPadding: const EdgeInsets.all(AppSpacing.base),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _hasPastedContent
                ? 'Content detected — tap Import Timetable to continue'
                : 'Paste the JSON from the AI or upload a .json file',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: _hasPastedContent ? colors.action : colors.borderMuted,
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _errorMessage != null
                ? Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: _buildErrorBox(_errorMessage!, colors),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_isProcessing || !_hasPastedContent)
                  ? null
                  : () => _importJsonString(_jsonController.text),
              icon: _isProcessing
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.onAction,
                      ),
                    )
                  : const Icon(Icons.file_download_rounded, size: 18),
              label: Text(_isProcessing ? 'Importing…' : 'Import Timetable'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.action,
                foregroundColor: colors.onAction,
                disabledBackgroundColor: colors.surfaceContainerHighest,
                disabledForegroundColor: colors.borderMuted,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              onPressed: _isProcessing ? null : _pickAndImportJson,
              icon: Icon(
                Icons.upload_file_rounded,
                size: 18,
                color: colors.borderMuted,
              ),
              label: Text(
                'Or upload a .json file',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: colors.borderMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _requestNotifications() async {
    try {
      await NotificationService.init();
      final granted = await NotificationService.requestPermission();
      if (mounted) setState(() => _notificationsEnabled = granted);
    } catch (_) {}
  }

  Future<void> _requestAlarms() async {
    try {
      final granted = await NotificationService.requestExactAlarmPermission();
      if (mounted) setState(() => _alarmsEnabled = granted);
    } catch (_) {}
  }

  Widget _buildStepThree(RelationalColors colors) {
    return _stepCard(
      stepNumber: '3',
      title: 'Enable class reminders',
      body: 'Jadwal can notify you before each period starts. No spam — '
          'just a quick heads-up at the right time.',
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _notificationsEnabled ? null : _requestNotifications,
              icon: _notificationsEnabled
                  ? const Icon(Icons.check_circle, size: 18)
                  : const Icon(Icons.notifications_none_rounded, size: 18),
              label: Text(_notificationsEnabled
                  ? 'Notifications enabled'
                  : 'Enable Notifications'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _notificationsEnabled
                    ? colors.surfaceContainerHighest
                    : colors.action,
                foregroundColor: _notificationsEnabled
                    ? colors.textSecondary
                    : colors.onAction,
                disabledBackgroundColor: colors.surfaceContainerHighest,
                disabledForegroundColor: colors.textSecondary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _alarmsEnabled ? null : _requestAlarms,
              icon: _alarmsEnabled
                  ? const Icon(Icons.check_circle, size: 18)
                  : const Icon(Icons.alarm_rounded, size: 18),
              label: Text(_alarmsEnabled
                  ? 'Exact alarms enabled'
                  : 'Enable Alarms'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _alarmsEnabled
                    ? colors.surfaceContainerHighest
                    : colors.action,
                foregroundColor: _alarmsEnabled
                    ? colors.textSecondary
                    : colors.onAction,
                disabledBackgroundColor: colors.surfaceContainerHighest,
                disabledForegroundColor: colors.textSecondary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: TextButton(
              onPressed: _navigateToHome,
              style: TextButton.styleFrom(foregroundColor: colors.action),
              child: const Text('Start using Jadwal'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBox(String message, RelationalColors colors) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          color: colors.dangerSubtle,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: colors.danger.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: colors.danger, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: colors.danger,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepCard({
    required String stepNumber,
    required String title,
    required String body,
    required RelationalColors colors,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: stepNumber == '1' && _stepOneComplete
              ? colors.action.withValues(alpha: 0.5)
              : colors.borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.action,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  stepNumber,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: colors.onAction,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            body,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13.5,
              color: colors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

