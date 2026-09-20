import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:android_intent_plus/android_intent.dart';

import '../constants/spacing.dart';
import '../constants/timetable_prompt.dart';
import '../services/json_validator.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../theme/relational_colors.dart';
import '../widgets/app_feedback.dart';
import '../widgets/wavy_progress_bar.dart';
import 'home_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _jsonController = TextEditingController();
  final _scrollController = ScrollController();

  Map<String, dynamic>? _parsedTimetable;
  String? _lastCheckedClipboard;
  bool _hasPastedContent = false;
  bool _promptCopied = false;
  String? _recentlyLaunchedAi;
  bool _stepOneComplete = false;
  bool _showStepTwo = false;
  bool _showStepThree = false;
  bool _isProcessing = false;
  bool _showManualJsonEditor = false;
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
    WidgetsBinding.instance.addObserver(this);
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

    // Check clipboard on initial cold open in case user already copied it before launching
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkClipboardForTimetable(userInitiated: false);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _copyBounceController.dispose();
    _activeDotPulseController.dispose();
    _jsonController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_isProcessing && !_showStepThree) {
      _checkClipboardForTimetable(userInitiated: false);
    }
  }

  Future<void> _checkClipboardForTimetable({bool userInitiated = false}) async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim();
      if (text == null || text.isEmpty) {
        if (userInitiated && mounted) {
          AppFeedback.showInfo(context, 'Clipboard is empty');
        }
        return;
      }

      if (!userInitiated && text == _lastCheckedClipboard) return;
      _lastCheckedClipboard = text;

      final normalized = JsonValidator.tryParseAndNormalize(text);
      if (normalized != null) {
        if (!mounted) return;
        HapticFeedback.mediumImpact();
        setState(() {
          _parsedTimetable = normalized;
          _jsonController.text = const JsonEncoder.withIndent('  ').convert(normalized);
          _hasPastedContent = true;
          _stepOneComplete = true;
          _showStepTwo = true;
          _errorMessage = null;
        });
        final teacherName = normalized['teacher'] as String? ?? 'Teacher';
        AppFeedback.showSuccess(
          context,
          'Found timetable for $teacherName from clipboard!',
        );
        _scrollToStepTwo();
      } else if (userInitiated && mounted) {
        _jsonController.text = text;
        _parseAndSetCurrentText();
        AppFeedback.showSuccess(context, 'Pasted text from clipboard');
      }
    } catch (_) {}
  }

  void _parseAndSetCurrentText() {
    final raw = _jsonController.text.trim();
    if (raw.isEmpty) {
      setState(() => _parsedTimetable = null);
      return;
    }
    final normalized = JsonValidator.tryParseAndNormalize(raw);
    if (normalized != null) {
      setState(() {
        _parsedTimetable = normalized;
        _errorMessage = null;
        _showStepTwo = true;
      });
    } else {
      setState(() {
        _parsedTimetable = null;
      });
    }
  }

  Future<void> _launchAiAssistant({
    required String name,
    required String url,
  }) async {
    await Clipboard.setData(const ClipboardData(text: kTimetablePrompt));
    HapticFeedback.lightImpact();

    if (mounted) {
      setState(() {
        _promptCopied = true;
        _recentlyLaunchedAi = name;
        _stepOneComplete = true;
        _showStepTwo = true;
      });
      _copyBounceController.forward(from: 0.0);
      AppFeedback.showSuccess(
        context,
        'Prompt copied! Opening $name…',
      );
    }

    try {
      if (Platform.isAndroid) {
        final intent = AndroidIntent(
          action: 'action_view',
          data: url,
        );
        await intent.launch();
      }
    } catch (_) {}

    _scrollToStepTwo();
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) setState(() => _promptCopied = false);
  }

  Future<void> _copyPrompt() async {
    if (_promptCopied) return;
    await Clipboard.setData(const ClipboardData(text: kTimetablePrompt));
    HapticFeedback.lightImpact();
    setState(() {
      _promptCopied = true;
      _stepOneComplete = true;
      _showStepTwo = true;
    });
    _copyBounceController.forward(from: 0.0);
    if (mounted) {
      AppFeedback.showSuccess(context, 'Prompt copied to clipboard');
    }
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

  Future<void> _importCurrentTimetable() async {
    if (_parsedTimetable != null) {
      await _saveAndAdvance(_parsedTimetable!);
      return;
    }

    final raw = _jsonController.text.trim();
    if (raw.isEmpty) {
      setState(() {
        _errorMessage = 'Please copy a timetable from an AI or paste JSON to continue.';
      });
      return;
    }

    setState(() {
      _errorMessage = null;
      _isProcessing = true;
    });

    try {
      final cleaned = JsonValidator.sanitizeJson(raw);
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

      await _saveAndAdvance(validation.data!);
    } catch (e) {
      setState(() {
        _errorMessage = 'Something went wrong while importing: $e';
        _isProcessing = false;
      });
    }
  }

  Future<void> _saveAndAdvance(Map<String, dynamic> data) async {
    setState(() {
      _errorMessage = null;
      _isProcessing = true;
    });

    try {
      await StorageService.saveTimetable(data);

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
        _errorMessage = 'Something went wrong while saving: $e';
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
      final normalized = JsonValidator.tryParseAndNormalize(rawString);
      if (normalized != null) {
        setState(() {
          _parsedTimetable = normalized;
          _jsonController.text = const JsonEncoder.withIndent('  ').convert(normalized);
          _hasPastedContent = true;
          _showStepTwo = true;
          _isProcessing = false;
          _errorMessage = null;
        });
        if (mounted) {
          AppFeedback.showSuccess(
            context,
            'Timetable loaded from file!',
          );
        }
      } else {
        _jsonController.text = rawString;
        await _importCurrentTimetable();
      }
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
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.sm),
              // Brand Mark
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.actionSubtle,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.borderSubtle),
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
                  fontFamily: 'Geist',
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Set up your weekly timetable in seconds — works 100% offline.',
                style: TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 14.5,
                  color: colors.textSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              _buildProgressIndicator(colors),
              const SizedBox(height: AppSpacing.xl),
              if (!_showStepThree) ...[
                _buildStepOne(colors),
                if (_showStepTwo) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _buildStepTwo(colors),
                ],
              ] else ...[
                _buildCompletedSummary(colors),
                const SizedBox(height: AppSpacing.lg),
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
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
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
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Timetable Ready',
                  style: TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Your schedule is validated and saved offline.',
                  style: TextStyle(
                    fontFamily: 'Geist',
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
        const SizedBox(width: AppSpacing.sm),
        Text(
          'Step $step of 3',
          style: TextStyle(
            fontFamily: 'Geist',
            fontSize: 12,
            fontWeight: FontWeight.w600,
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
      title: 'Generate with AI',
      body: 'Tap an AI assistant below. We’ll automatically copy the prompt and open the app. '
          'Simply attach your timetable photo, paste the prompt, and copy the reply.',
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1-Tap AI Quick-Launch Action Grid
          _buildAiLauncherButton(
            title: 'Google Gemini',
            subtitle: 'Recommended • Fast photo recognition',
            icon: Icons.auto_awesome_rounded,
            badge: 'Fast',
            onTap: () => _launchAiAssistant(
              name: 'Google Gemini',
              url: 'https://gemini.google.com/',
            ),
            colors: colors,
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildAiLauncherButton(
            title: 'ChatGPT',
            subtitle: 'OpenAI • Reasoning models',
            icon: Icons.chat_bubble_outline_rounded,
            badge: null,
            onTap: () => _launchAiAssistant(
              name: 'ChatGPT',
              url: 'https://chatgpt.com/',
            ),
            colors: colors,
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildAiLauncherButton(
            title: 'Claude',
            subtitle: 'Anthropic • Detailed table extraction',
            icon: Icons.table_chart_outlined,
            badge: null,
            onTap: () => _launchAiAssistant(
              name: 'Claude',
              url: 'https://claude.ai/',
            ),
            colors: colors,
          ),
          const SizedBox(height: AppSpacing.md),

          // Secondary Action: Just Copy Prompt (for DeepSeek, Copilot, Desktop)
          AnimatedBuilder(
            animation: _copyBounceScale,
            builder: (context, child) => Transform.scale(
              scale: _copyBounceScale.value,
              child: child,
            ),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _copyPrompt,
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                  child: Icon(
                    _promptCopied ? Icons.check_rounded : Icons.copy_rounded,
                    key: ValueKey(_promptCopied),
                    size: 16,
                    color: colors.action,
                  ),
                ),
                label: Text(
                  _promptCopied ? 'Prompt copied!' : 'Just Copy Prompt (DeepSeek / Other)',
                  style: TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.action,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: colors.borderSubtle),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ),

          if (_stepOneComplete) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colors.actionSubtle,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.borderSubtle),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline_rounded, size: 16, color: colors.action),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _recentlyLaunchedAi != null
                          ? 'Prompt copied! Switched to $_recentlyLaunchedAi. Return here when you copy the result.'
                          : 'Prompt copied! Paste it into your AI with your photo.',
                      style: TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 12,
                        color: colors.action,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (!_showStepTwo) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  setState(() => _showStepTwo = true);
                  _scrollToStepTwo();
                },
                icon: Icon(Icons.arrow_downward_rounded, size: 16, color: colors.action),
                label: Text(
                  'Already have timetable data? Continue to Step 2 →',
                  style: TextStyle(
                    fontFamily: 'Geist',
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

  Widget _buildAiLauncherButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required String? badge,
    required VoidCallback onTap,
    required RelationalColors colors,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: colors.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.borderSubtle),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colors.actionSubtle,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 18, color: colors.action),
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
                            title,
                            style: TextStyle(
                              fontFamily: 'Geist',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: colors.action,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              badge,
                              style: TextStyle(
                                fontFamily: 'Geist',
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: colors.onAction,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.open_in_new_rounded,
                size: 16,
                color: colors.borderMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepTwo(RelationalColors colors) {
    final hasParsed = _parsedTimetable != null;

    return _stepCard(
      stepNumber: '2',
      title: 'Review & Import',
      body: hasParsed
          ? 'Timetable verified! Review your schedule details below and tap Import.'
          : 'Copy the AI response and return to Jadwal — we’ll automatically grab it from your clipboard.',
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // If parsed, display the Visual Timetable Preview Card!
          if (hasParsed) ...[
            _buildVisualTimetablePreviewCard(_parsedTimetable!, colors),
            const SizedBox(height: AppSpacing.md),
          ] else ...[
            // Listening State Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.base),
              decoration: BoxDecoration(
                color: colors.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.borderSubtle),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      AnimatedBuilder(
                        animation: _activeDotPulseScale,
                        builder: (context, child) => Transform.scale(
                          scale: _activeDotPulseScale.value,
                          child: child,
                        ),
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: colors.action,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Waiting for timetable data…',
                          style: TextStyle(
                            fontFamily: 'Geist',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Copy the response from your AI and reopen this screen. Jadwal will automatically detect it.',
                    style: TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 12,
                      color: colors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: () => _checkClipboardForTimetable(userInitiated: true),
                      icon: const Icon(Icons.content_paste_rounded, size: 16),
                      label: const Text('Paste from Clipboard'),
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.actionSubtle,
                        foregroundColor: colors.action,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // Error box if something failed
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _errorMessage != null
                ? Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _buildErrorBox(_errorMessage!, colors),
                  )
                : const SizedBox.shrink(),
          ),

          // Primary Import Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_isProcessing || (!hasParsed && !_hasPastedContent))
                  ? null
                  : _importCurrentTimetable,
              icon: _isProcessing
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.onAction,
                      ),
                    )
                  : const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(
                _isProcessing
                    ? 'Importing…'
                    : (hasParsed ? 'Import This Schedule' : 'Import Timetable'),
                style: const TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
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

          const SizedBox(height: AppSpacing.sm),

          // Expandable Power-User manual editor
          Center(
            child: TextButton.icon(
              onPressed: () {
                setState(() => _showManualJsonEditor = !_showManualJsonEditor);
              },
              icon: Icon(
                _showManualJsonEditor
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.code_rounded,
                size: 16,
                color: colors.textSecondary,
              ),
              label: Text(
                _showManualJsonEditor
                    ? 'Hide manual JSON editor'
                    : 'Inspect / edit JSON manually or upload file',
                style: TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 12,
                  color: colors.textSecondary,
                ),
              ),
            ),
          ),

          if (_showManualJsonEditor) ...[
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _jsonController,
              maxLines: 8,
              minLines: 4,
              enabled: !_isProcessing,
              onChanged: (_) => _parseAndSetCurrentText(),
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12,
                color: colors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: '{\n  "teacher": "Dr. Smith",\n  "timetable": { ... }\n}',
                hintStyle: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 12,
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
            const SizedBox(height: AppSpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: _isProcessing ? null : _pickAndImportJson,
                  icon: Icon(Icons.upload_file_rounded, size: 16, color: colors.action),
                  label: Text(
                    'Upload .json file',
                    style: TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.action,
                    ),
                  ),
                ),
                if (hasParsed)
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _parsedTimetable = null;
                        _jsonController.clear();
                      });
                    },
                    icon: Icon(Icons.refresh_rounded, size: 16, color: colors.danger),
                    label: Text(
                      'Clear',
                      style: TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 12,
                        color: colors.danger,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVisualTimetablePreviewCard(
    Map<String, dynamic> data,
    RelationalColors colors,
  ) {
    final teacherName = data['teacher'] as String? ?? 'Teacher';
    final timetableMap = data['timetable'] as Map<String, dynamic>? ?? {};

    int totalClasses = 0;
    final List<String> activeDays = [];
    String? firstStart;
    String? lastEnd;

    for (final day in kDayKeys) {
      final periods = timetableMap[day];
      if (periods is List && periods.isNotEmpty) {
        totalClasses += periods.length;
        activeDays.add(day[0].toUpperCase() + day.substring(1, 3));
        for (final p in periods) {
          if (p is Map) {
            firstStart ??= p['start']?.toString();
            lastEnd = p['end']?.toString() ?? lastEnd;
          }
        }
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.action.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colors.actionSubtle,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.school_rounded, color: colors.action, size: 20),
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
                            teacherName,
                            style: TextStyle(
                              fontFamily: 'Geist',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: colors.actionSubtle,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'DETECTED',
                            style: TextStyle(
                              fontFamily: 'Geist',
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: colors.action,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ready to import offline',
                      style: TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.borderSubtle),
            ),
            child: Row(
              children: [
                _buildSummaryStat(
                  label: 'Classes',
                  value: '$totalClasses periods',
                  colors: colors,
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: colors.borderSubtle,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                ),
                _buildSummaryStat(
                  label: 'Teaching Days',
                  value: '${activeDays.length} days (${activeDays.join(', ')})',
                  colors: colors,
                ),
              ],
            ),
          ),
          if (firstStart != null && lastEnd != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 14, color: colors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  'Daily span: $firstStart – $lastEnd',
                  style: TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 12,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryStat({
    required String label,
    required String value,
    required RelationalColors colors,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: 'Geist',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Geist',
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
          const SizedBox(height: AppSpacing.sm),
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
          const SizedBox(height: AppSpacing.md),
          Center(
            child: TextButton(
              onPressed: _navigateToHome,
              style: TextButton.styleFrom(foregroundColor: colors.action),
              child: const Text('Start using Jadwal →'),
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
                  fontFamily: 'Geist',
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
                    fontFamily: 'Geist',
                    color: colors.onAction,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            body,
            style: TextStyle(
              fontFamily: 'Geist',
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
