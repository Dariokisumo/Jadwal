import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';

import '../constants/spacing.dart';
import '../constants/timetable_prompt.dart';
import '../services/deep_link_service.dart';
import '../services/json_validator.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../theme/relational_colors.dart';
import '../widgets/app_feedback.dart';
import '../widgets/brand_icons.dart';
import 'home_screen.dart';

/// Pre-populated demo schedule for instant preview and testing.
const Map<String, dynamic> kSampleTimetable = {
  'teacher': 'Demo Teacher',
  'timetable': {
    'saturday': [
      {
        'period': 1,
        'subject': 'ENG',
        'classroom': 'Room 101',
        'start': '8:30 AM',
        'end': '9:15 AM'
      },
      {
        'period': 2,
        'subject': 'MATH',
        'classroom': 'Room 104',
        'start': '9:20 AM',
        'end': '10:05 AM'
      },
      {
        'period': 3,
        'subject': 'SCI',
        'classroom': 'Lab 2',
        'start': '10:20 AM',
        'end': '11:05 AM'
      }
    ],
    'sunday': [
      {
        'period': 1,
        'subject': 'HIS',
        'classroom': 'Room 102',
        'start': '8:30 AM',
        'end': '9:15 AM'
      },
      {
        'period': 2,
        'subject': 'ENG',
        'classroom': 'Room 101',
        'start': '9:20 AM',
        'end': '10:05 AM'
      }
    ],
    'monday': [
      {
        'period': 1,
        'subject': 'MATH',
        'classroom': 'Room 104',
        'start': '8:30 AM',
        'end': '9:15 AM'
      },
      {
        'period': 2,
        'subject': 'GEO',
        'classroom': 'Room 103',
        'start': '9:20 AM',
        'end': '10:05 AM'
      },
      {
        'period': 4,
        'subject': 'ART',
        'classroom': 'Studio 1',
        'start': '11:15 AM',
        'end': '12:00 PM'
      }
    ],
    'tuesday': [
      {
        'period': 1,
        'subject': 'SCI',
        'classroom': 'Lab 2',
        'start': '8:30 AM',
        'end': '9:15 AM'
      },
      {
        'period': 3,
        'subject': 'ENG',
        'classroom': 'Room 101',
        'start': '10:20 AM',
        'end': '11:05 AM'
      }
    ],
    'wednesday': [
      {
        'period': 2,
        'subject': 'MATH',
        'classroom': 'Room 104',
        'start': '9:20 AM',
        'end': '10:05 AM'
      },
      {
        'period': 3,
        'subject': 'PE',
        'classroom': 'Gym',
        'start': '10:20 AM',
        'end': '11:05 AM'
      }
    ],
    'thursday': [
      {
        'period': 1,
        'subject': 'HIS',
        'classroom': 'Room 102',
        'start': '8:30 AM',
        'end': '9:15 AM'
      }
    ]
  }
};

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> with WidgetsBindingObserver {
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

  // Native assistant app detection
  bool _geminiInstalled = false;
  bool _chatGptInstalled = false;
  bool _claudeInstalled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _jsonController.addListener(() {
      final hasContent = _jsonController.text.trim().isNotEmpty;
      if (hasContent != _hasPastedContent) {
        setState(() => _hasPastedContent = hasContent);
      }
      if (_errorMessage != null) {
        setState(() => _errorMessage = null);
      }
    });

    _detectInstalledApps();

    // Check clipboard on initial cold open in case user already copied it before launching
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkClipboardForTimetable(userInitiated: false);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _jsonController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_isProcessing && !_showStepThree) {
      _detectInstalledApps();
      _checkClipboardForTimetable(userInitiated: false);
    }
  }

  Future<void> _detectInstalledApps() async {
    final gemini = await DeepLinkService.isAppInstalled('com.google.android.apps.bard');
    final chatgpt = await DeepLinkService.isAppInstalled('com.openai.chatgpt');
    final claude = await DeepLinkService.isAppInstalled('com.anthropic.claude');
    if (mounted) {
      setState(() {
        _geminiInstalled = gemini;
        _chatGptInstalled = chatgpt;
        _claudeInstalled = claude;
      });
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

  Future<void> _launchAssistant({
    required String name,
    required String packageName,
    required String fallbackUrl,
    required bool isInstalled,
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
      AppFeedback.showSuccess(
        context,
        'Prompt copied! Opening $name (${isInstalled ? 'App' : 'Web'})…',
      );
    }

    try {
      await DeepLinkService.launchAppOrUrl(
        packageName: packageName,
        fallbackUrl: fallbackUrl,
      );
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
    if (mounted) {
      AppFeedback.showSuccess(context, 'Prompt copied to clipboard');
    }
    _scrollToStepTwo();
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _promptCopied = false);
  }

  void _loadSampleTimetable() {
    HapticFeedback.mediumImpact();
    setState(() {
      _parsedTimetable = kSampleTimetable;
      _jsonController.text = const JsonEncoder.withIndent('  ').convert(kSampleTimetable);
      _hasPastedContent = true;
      _stepOneComplete = true;
      _showStepTwo = true;
      _errorMessage = null;
    });
    AppFeedback.showSuccess(
      context,
      'Loaded sample schedule for Demo Teacher!',
    );
    _scrollToStepTwo();
  }

  void _scrollToStepTwo() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
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
        _errorMessage = 'Please copy a timetable or paste JSON to continue.';
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
              'This is not valid JSON. Make sure the timetable is in the correct format.';
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
        transitionDuration: Duration(milliseconds: reduced ? 0 : 350),
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionsBuilder: (_, animation, __, child) {
          final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
          final scale = Tween(begin: 0.98, end: 1.0).animate(fade);
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
        type: FileType.custom,
        allowedExtensions: ['json', 'jadwal'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _isProcessing = false);
        return;
      }

      final fileName = result.files.single.name;
      final fileBytes = result.files.single.bytes;
      if (fileBytes == null) {
        setState(() {
          _errorMessage = 'Could not read "$fileName". Please try again.';
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
        _errorMessage = 'Error reading file: $e';
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.relColors;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.xs),
              // App Brand Header
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colors.actionSubtle,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.schedule_rounded,
                      color: colors.action,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Jadwal',
                          style: TextStyle(
                            fontFamily: 'Geist',
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          'Offline timetable tracker',
                          style: TextStyle(
                            fontFamily: 'Geist',
                            fontSize: 13,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              // Calm Progress Indicator
              _buildProgressIndicator(colors),
              const SizedBox(height: AppSpacing.lg),
              if (!_showStepThree) ...[
                _buildStepOne(colors),
                if (_showStepTwo) ...[
                  const SizedBox(height: AppSpacing.md),
                  _buildStepTwo(colors),
                ],
              ] else ...[
                _buildCompletedSummary(colors),
                const SizedBox(height: AppSpacing.md),
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
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colors.actionSubtle,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.check_circle_rounded,
              color: colors.action,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Schedule Validated',
                  style: TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Timetable saved offline and ready to use.',
                  style: TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 12.5,
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
    final currentStep = _showStepThree ? 3 : (_showStepTwo ? 2 : 1);
    return Row(
      children: [
        _progressCircle(1, currentStep >= 1, currentStep == 1, colors),
        Expanded(
          child: Container(
            height: 2,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: currentStep >= 2 ? colors.action : colors.borderSubtle,
          ),
        ),
        _progressCircle(2, currentStep >= 2, currentStep == 2, colors),
        Expanded(
          child: Container(
            height: 2,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: currentStep >= 3 ? colors.action : colors.borderSubtle,
          ),
        ),
        _progressCircle(3, currentStep >= 3, currentStep == 3, colors),
        const SizedBox(width: AppSpacing.md),
        Text(
          'Step $currentStep of 3',
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

  Widget _progressCircle(int number, bool reached, bool active, RelationalColors colors) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: reached ? colors.action : colors.surfaceContainerHighest,
        shape: BoxShape.circle,
        border: active ? Border.all(color: colors.surface, width: 2) : null,
      ),
      child: Text(
        '$number',
        style: TextStyle(
          fontFamily: 'Geist',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: reached ? colors.onAction : colors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildStepOne(RelationalColors colors) {
    return _stepCard(
      stepNumber: '1',
      title: 'Get Timetable Prompt',
      body: 'Copy our extraction prompt, paste it into your preferred assistant along with a photo of your timetable, then copy the result.',
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Primary Action: Copy Prompt
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _copyPrompt,
              icon: Icon(
                _promptCopied ? Icons.check_circle_rounded : Icons.copy_rounded,
                size: 18,
              ),
              label: Text(
                _promptCopied ? 'Prompt Copied to Clipboard!' : 'Copy AI Prompt',
                style: const TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: colors.action,
                foregroundColor: colors.onAction,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Assistant Selector Header
          Text(
            'Or launch with an assistant:',
            style: TextStyle(
              fontFamily: 'Geist',
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Horizontal 3-card assistant grid
          Row(
            children: [
              Expanded(
                child: _buildAssistantChip(
                  name: 'Gemini',
                  icon: const GeminiBrandIcon(size: 22),
                  isInstalled: _geminiInstalled,
                  onTap: () => _launchAssistant(
                    name: 'Gemini',
                    packageName: 'com.google.android.apps.bard',
                    fallbackUrl: 'https://gemini.google.com/',
                    isInstalled: _geminiInstalled,
                  ),
                  colors: colors,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _buildAssistantChip(
                  name: 'ChatGPT',
                  icon: const ChatGptBrandIcon(size: 22),
                  isInstalled: _chatGptInstalled,
                  onTap: () => _launchAssistant(
                    name: 'ChatGPT',
                    packageName: 'com.openai.chatgpt',
                    fallbackUrl: 'https://chatgpt.com/',
                    isInstalled: _chatGptInstalled,
                  ),
                  colors: colors,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _buildAssistantChip(
                  name: 'Claude',
                  icon: const ClaudeBrandIcon(size: 22),
                  isInstalled: _claudeInstalled,
                  onTap: () => _launchAssistant(
                    name: 'Claude',
                    packageName: 'com.anthropic.claude',
                    fallbackUrl: 'https://claude.ai/',
                    isInstalled: _claudeInstalled,
                  ),
                  colors: colors,
                ),
              ),
            ],
          ),

          if (_stepOneComplete) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: colors.actionSubtle,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline_rounded, size: 16, color: colors.action),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _recentlyLaunchedAi != null
                          ? 'Prompt copied! Reopen Jadwal after copying result from $_recentlyLaunchedAi.'
                          : 'Prompt copied! Paste it with your schedule image into your assistant.',
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

          const SizedBox(height: AppSpacing.sm),
          // Quiet secondary actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: _loadSampleTimetable,
                icon: Icon(Icons.play_circle_outline_rounded, size: 16, color: colors.textSecondary),
                label: Text(
                  'Try Sample Timetable',
                  style: TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: colors.textSecondary,
                  ),
                ),
              ),
              if (!_showStepTwo)
                TextButton.icon(
                  onPressed: () {
                    setState(() => _showStepTwo = true);
                    _scrollToStepTwo();
                  },
                  icon: Icon(Icons.arrow_downward_rounded, size: 16, color: colors.action),
                  label: Text(
                    'Continue →',
                    style: TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: colors.action,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAssistantChip({
    required String name,
    required Widget icon,
    required bool isInstalled,
    required VoidCallback onTap,
    required RelationalColors colors,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            color: colors.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.borderSubtle),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.borderSubtle.withValues(alpha: 0.6)),
                ),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: Center(child: icon),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                name,
                style: TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isInstalled ? colors.actionSubtle : colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isInstalled ? 'App' : 'Web',
                  style: TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isInstalled ? colors.action : colors.textSecondary,
                  ),
                ),
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
          ? 'Timetable verified! Review the schedule details below and tap Import.'
          : 'Copy the assistant\'s reply and reopen Jadwal — we’ll automatically grab it from your clipboard.',
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasParsed) ...[
            _buildVisualTimetablePreviewCard(_parsedTimetable!, colors),
            const SizedBox(height: AppSpacing.md),
          ] else ...[
            // Quiet Listening State Box (Static status, no looping animation)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.base),
              decoration: BoxDecoration(
                color: colors.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                      Text(
                        'Waiting for timetable data…',
                        style: TextStyle(
                          fontFamily: 'Geist',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Copy the response from your AI and return to Jadwal. We’ll auto-detect it from your clipboard.',
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

          if (_errorMessage != null) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _buildErrorBox(_errorMessage!, colors),
            ),
          ],

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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // Clean expandable raw JSON editor
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
                    ? 'Hide raw text input'
                    : 'Paste raw text or upload file',
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
              maxLines: 6,
              minLines: 3,
              enabled: !_isProcessing,
              onChanged: (_) => _parseAndSetCurrentText(),
              style: TextStyle(
                fontFamily: 'Geist',
                fontSize: 12.5,
                color: colors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Paste timetable JSON here…',
                hintStyle: TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 12.5,
                  color: colors.textSecondary,
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
                contentPadding: const EdgeInsets.all(AppSpacing.md),
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
                    'Upload .jadwal / .json',
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.action.withValues(alpha: 0.35), width: 1.5),
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
                  color: colors.actionSubtle,
                  borderRadius: BorderRadius.circular(9),
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
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: colors.actionSubtle,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'VERIFIED',
                            style: TextStyle(
                              fontFamily: 'Geist',
                              fontSize: 10,
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
          Row(
            children: [
              _buildSummaryStat(
                label: 'Classes',
                value: '$totalClasses periods',
                colors: colors,
              ),
              _buildSummaryStat(
                label: 'Days',
                value: '${activeDays.length} (${activeDays.join(', ')})',
                colors: colors,
              ),
            ],
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
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Geist',
              fontSize: 13,
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
      title: 'Class Reminders',
      body: 'Jadwal alerts you before each period starts. Works completely offline without draining battery.',
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: TextButton(
              onPressed: _navigateToHome,
              style: TextButton.styleFrom(
                foregroundColor: colors.action,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              child: const Text(
                'Start using Jadwal →',
                style: TextStyle(fontFamily: 'Geist', fontSize: 14, fontWeight: FontWeight.w600),
              ),
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
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: stepNumber == '1' && _stepOneComplete
              ? colors.action.withValues(alpha: 0.35)
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
              fontSize: 13,
              color: colors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          child,
        ],
      ),
    );
  }
}
