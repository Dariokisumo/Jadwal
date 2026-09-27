import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/spacing.dart';
import '../constants/timetable_prompt.dart';
import '../services/deep_link_service.dart';
import '../services/image_alignment_service.dart';
import '../theme/relational_colors.dart';
import 'app_feedback.dart';
import 'brand_icons.dart';

/// Interactive modal sheet that lets teachers align, rotate, and frame
/// their paper timetable photo, and directly share it to AI assistants
/// with the extraction prompt pre-copied to clipboard.
class PhotoAlignmentSheet extends StatefulWidget {
  final Uint8List imageBytes;
  final String? originalPath;
  final bool geminiInstalled;
  final bool chatGptInstalled;
  final bool claudeInstalled;
  final void Function(String assistantName) onShared;

  const PhotoAlignmentSheet({
    super.key,
    required this.imageBytes,
    this.originalPath,
    required this.geminiInstalled,
    required this.chatGptInstalled,
    required this.claudeInstalled,
    required this.onShared,
  });

  /// Convenient helper to display the sheet in modern relational styling.
  static Future<void> show(
    BuildContext context, {
    required Uint8List imageBytes,
    String? originalPath,
    required bool geminiInstalled,
    required bool chatGptInstalled,
    required bool claudeInstalled,
    required void Function(String assistantName) onShared,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PhotoAlignmentSheet(
        imageBytes: imageBytes,
        originalPath: originalPath,
        geminiInstalled: geminiInstalled,
        chatGptInstalled: chatGptInstalled,
        claudeInstalled: claudeInstalled,
        onShared: onShared,
      ),
    );
  }

  @override
  State<PhotoAlignmentSheet> createState() => _PhotoAlignmentSheetState();
}

class _PhotoAlignmentSheetState extends State<PhotoAlignmentSheet> {
  final TransformationController _transformController =
      TransformationController();
  int _quarterTurns = 0;
  bool _showGrid = true;
  bool _isSharing = false;
  String? _sharingTarget;

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _rotateClockwise() {
    HapticFeedback.lightImpact();
    setState(() {
      _quarterTurns = (_quarterTurns + 1) % 4;
      _transformController.value = Matrix4.identity();
    });
  }

  void _toggleGrid() {
    HapticFeedback.selectionClick();
    setState(() {
      _showGrid = !_showGrid;
    });
  }

  void _resetTransform() {
    HapticFeedback.lightImpact();
    setState(() {
      _quarterTurns = 0;
      _transformController.value = Matrix4.identity();
    });
  }

  Future<void> _shareToAssistant({
    required String name,
    String? packageName,
  }) async {
    if (_isSharing) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _isSharing = true;
      _sharingTarget = name;
    });

    try {
      // 1. Copy prompt to clipboard
      await Clipboard.setData(const ClipboardData(text: kTimetablePrompt));

      // 2. Prepare (rotate & save) image
      final filePath = await ImageAlignmentService.prepareImageForShare(
        bytes: widget.imageBytes,
        quarterTurns: _quarterTurns,
        originalPath: widget.originalPath,
      );

      // 3. Dispatch native share intent
      await DeepLinkService.shareImageFile(
        filePath: filePath,
        title: 'Share Timetable to $name',
        text: kTimetablePrompt,
        packageName: packageName,
      );

      if (!mounted) return;
      widget.onShared(name);
      setState(() {
        _isSharing = false;
        _sharingTarget = null;
      });
      Navigator.of(context).maybePop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSharing = false;
          _sharingTarget = null;
        });
        AppFeedback.showError(context, 'Could not share photo: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.relColors;
    final mediaQuery = MediaQuery.of(context);
    final isReducedMotion = mediaQuery.disableAnimations;
    final maxSheetHeight = mediaQuery.size.height * 0.90;
    final viewfinderHeight = (mediaQuery.size.height * 0.33).clamp(180.0, 270.0);

    return Container(
      constraints: BoxConstraints(maxHeight: maxSheetHeight),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          top: BorderSide(color: colors.borderSubtle, width: 1),
          left: BorderSide(color: colors.borderSubtle, width: 1),
          right: BorderSide(color: colors.borderSubtle, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.base,
            AppSpacing.sm,
            AppSpacing.base,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: colors.borderMuted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: colors.actionSubtle,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.crop_rotate_rounded,
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
                          'Align Timetable Photo',
                          style: TextStyle(
                            fontFamily: 'Geist',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          'Ensure columns are upright and readable',
                          style: TextStyle(
                            fontFamily: 'Geist',
                            fontSize: 12,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: colors.textSecondary),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Viewfinder Canvas
              _buildViewfinder(colors, isReducedMotion, viewfinderHeight),
              const SizedBox(height: AppSpacing.md),

              // Pre-flight Guidance Checklist
              _buildGuidanceBar(colors),
              const SizedBox(height: AppSpacing.md),

              // Prompt copy reminder
              _buildPromptNotice(colors),
              const SizedBox(height: AppSpacing.lg),

              // Direct AI Share Targets
              _buildShareSection(colors),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildViewfinder(
    RelationalColors colors,
    bool isReducedMotion,
    double height,
  ) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Interactive image with rotation
          InteractiveViewer(
            transformationController: _transformController,
            minScale: 0.6,
            maxScale: 4.0,
            boundaryMargin: const EdgeInsets.all(40),
            child: Center(
              child: RotatedBox(
                quarterTurns: _quarterTurns % 4,
                child: Image.memory(
                  widget.imageBytes,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),

          // Custom alignment overlay (Corner ticks & grid)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _AlignmentOverlayPainter(
                  cornerColor: colors.action,
                  gridColor: colors.action.withValues(alpha: 0.22),
                  showGrid: _showGrid,
                ),
              ),
            ),
          ),

          // Bottom floating controls pill with overflow defense
          Positioned(
            bottom: AppSpacing.sm,
            left: AppSpacing.sm,
            right: AppSpacing.sm,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surface.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: colors.borderSubtle),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Rotate Button
                      _ViewfinderButton(
                        icon: Icons.rotate_right_rounded,
                        label: '${(_quarterTurns % 4) * 90}°',
                        tooltip: 'Rotate 90° clockwise',
                        onPressed: _rotateClockwise,
                        colors: colors,
                      ),
                      _verticalDivider(colors),
                      // Grid Toggle Button
                      _ViewfinderButton(
                        icon: _showGrid
                            ? Icons.grid_on_rounded
                            : Icons.grid_off_rounded,
                        label: 'Grid',
                        isActive: _showGrid,
                        tooltip: _showGrid ? 'Hide grid' : 'Show alignment grid',
                        onPressed: _toggleGrid,
                        colors: colors,
                      ),
                      _verticalDivider(colors),
                      // Reset Button
                      _ViewfinderButton(
                        icon: Icons.restart_alt_rounded,
                        label: 'Reset',
                        tooltip: 'Reset view and angle',
                        onPressed: _resetTransform,
                        colors: colors,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _verticalDivider(RelationalColors colors) {
    return Container(
      width: 1,
      height: 18,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: colors.borderSubtle,
    );
  }

  Widget _buildGuidanceBar(RelationalColors colors) {
    return Row(
      children: [
        Expanded(
          child: _GuidanceChip(
            icon: Icons.check_circle_outline_rounded,
            label: 'Level & straight',
            colors: colors,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: _GuidanceChip(
            icon: Icons.aspect_ratio_rounded,
            label: 'All days visible',
            colors: colors,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: _GuidanceChip(
            icon: Icons.wb_sunny_outlined,
            label: 'Clear lighting',
            colors: colors,
          ),
        ),
      ],
    );
  }

  Widget _buildPromptNotice(RelationalColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: colors.actionSubtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.action.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.assignment_turned_in_rounded,
            size: 18,
            color: colors.action,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'The prompt will be automatically copied to your clipboard when you share.',
              style: TextStyle(
                fontFamily: 'Geist',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colors.action,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShareSection(RelationalColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SHARE PHOTO & PROMPT TO:',
          style: TextStyle(
            fontFamily: 'Geist',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _AssistantShareTile(
                name: 'Gemini',
                icon: const BrandIcon(
                  icon: BrandIcon.geminiIcon,
                  color: BrandIcon.geminiColor,
                  size: 20,
                ),
                isInstalled: widget.geminiInstalled,
                isLoading: _isSharing && _sharingTarget == 'Gemini',
                onTap: () => _shareToAssistant(
                  name: 'Gemini',
                  packageName: widget.geminiInstalled
                      ? 'com.google.android.apps.bard'
                      : null,
                ),
                colors: colors,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _AssistantShareTile(
                name: 'ChatGPT',
                icon: const BrandIcon(
                  icon: BrandIcon.chatGptIcon,
                  color: BrandIcon.chatGptColor,
                  size: 20,
                ),
                isInstalled: widget.chatGptInstalled,
                isLoading: _isSharing && _sharingTarget == 'ChatGPT',
                onTap: () => _shareToAssistant(
                  name: 'ChatGPT',
                  packageName: widget.chatGptInstalled
                      ? 'com.openai.chatgpt'
                      : null,
                ),
                colors: colors,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _AssistantShareTile(
                name: 'Claude',
                icon: const BrandIcon(
                  icon: BrandIcon.claudeIcon,
                  color: BrandIcon.claudeColor,
                  size: 20,
                ),
                isInstalled: widget.claudeInstalled,
                isLoading: _isSharing && _sharingTarget == 'Claude',
                onTap: () => _shareToAssistant(
                  name: 'Claude',
                  packageName: widget.claudeInstalled
                      ? 'com.anthropic.claude'
                      : null,
                ),
                colors: colors,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _AssistantShareTile(
                name: 'More',
                icon: Icon(
                  Icons.share_rounded,
                  color: colors.action,
                  size: 20,
                ),
                isInstalled: true,
                isLoading: _isSharing && _sharingTarget == 'More',
                onTap: () => _shareToAssistant(name: 'More'),
                colors: colors,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ViewfinderButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String tooltip;
  final bool isActive;
  final VoidCallback onPressed;
  final RelationalColors colors;

  const _ViewfinderButton({
    required this.icon,
    required this.label,
    required this.tooltip,
    this.isActive = false,
    required this.onPressed,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = isActive ? colors.action : colors.textPrimary;

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: effectiveColor),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: effectiveColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GuidanceChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final RelationalColors colors;

  const _GuidanceChip({
    required this.icon,
    required this.label,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: colors.surfaceContainer,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.borderSubtle),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 13, color: colors.action),
            const SizedBox(width: 4),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: colors.textSecondary,
                  ),
                  maxLines: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssistantShareTile extends StatelessWidget {
  final String name;
  final Widget icon;
  final bool isInstalled;
  final bool isLoading;
  final VoidCallback onTap;
  final RelationalColors colors;

  const _AssistantShareTile({
    required this.name,
    required this.icon,
    required this.isInstalled,
    required this.isLoading,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final availability = isInstalled ? 'App' : 'Web';
    return Semantics(
      button: true,
      label: 'Share to $name ($availability)',
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          decoration: BoxDecoration(
            color: colors.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.borderSubtle),
          ),
          child: isLoading
              ? Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.action,
                    ),
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    icon,
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        name,
                        style: TextStyle(
                          fontFamily: 'Geist',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                        maxLines: 1,
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        availability,
                        style: TextStyle(
                          fontFamily: 'Geist',
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
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
}

/// Custom painter that renders document framing corner brackets and
/// an optional 3x3 alignment rule-of-thirds grid.
class _AlignmentOverlayPainter extends CustomPainter {
  final Color cornerColor;
  final Color gridColor;
  final bool showGrid;

  _AlignmentOverlayPainter({
    required this.cornerColor,
    required this.gridColor,
    required this.showGrid,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 16.0;
    const tickLen = 22.0;
    const strokeWidth = 2.5;

    final tickPaint = Paint()
      ..color = cornerColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final left = pad;
    final top = pad;
    final right = size.width - pad;
    final bottom = size.height - pad;

    // 1. Draw 3x3 grid lines if enabled
    if (showGrid) {
      final gridPaint = Paint()
        ..color = gridColor
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;

      final wStep = (right - left) / 3.0;
      final hStep = (bottom - top) / 3.0;

      // Vertical grid lines
      canvas.drawLine(
        Offset(left + wStep, top),
        Offset(left + wStep, bottom),
        gridPaint,
      );
      canvas.drawLine(
        Offset(left + 2 * wStep, top),
        Offset(left + 2 * wStep, bottom),
        gridPaint,
      );

      // Horizontal grid lines
      canvas.drawLine(
        Offset(left, top + hStep),
        Offset(right, top + hStep),
        gridPaint,
      );
      canvas.drawLine(
        Offset(left, top + 2 * hStep),
        Offset(right, top + 2 * hStep),
        gridPaint,
      );
    }

    // 2. Draw 4 Corner Brackets
    // Top-Left
    canvas.drawLine(Offset(left, top), Offset(left + tickLen, top), tickPaint);
    canvas.drawLine(Offset(left, top), Offset(left, top + tickLen), tickPaint);

    // Top-Right
    canvas.drawLine(Offset(right, top), Offset(right - tickLen, top), tickPaint);
    canvas.drawLine(Offset(right, top), Offset(right, top + tickLen), tickPaint);

    // Bottom-Left
    canvas.drawLine(Offset(left, bottom), Offset(left + tickLen, bottom), tickPaint);
    canvas.drawLine(Offset(left, bottom), Offset(left, bottom - tickLen), tickPaint);

    // Bottom-Right
    canvas.drawLine(Offset(right, bottom), Offset(right - tickLen, bottom), tickPaint);
    canvas.drawLine(Offset(right, bottom), Offset(right, bottom - tickLen), tickPaint);
  }

  @override
  bool shouldRepaint(covariant _AlignmentOverlayPainter oldDelegate) {
    return oldDelegate.cornerColor != cornerColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.showGrid != showGrid;
  }
}
