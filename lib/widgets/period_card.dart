import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/period_visuals.dart';
import '../models/period_model.dart';
import '../theme/relational_colors.dart';
import 'wavy_progress_bar.dart';

class PeriodCard extends StatefulWidget {
  final Period period;
  final bool showStatus;
  final bool isVeryNext;
  final bool isManuallyFinished;
  final VoidCallback? onToggleFinished;

  const PeriodCard({
    super.key,
    required this.period,
    this.showStatus = true,
    this.isVeryNext = false,
    this.isManuallyFinished = false,
    this.onToggleFinished,
  });

  @override
  State<PeriodCard> createState() => _PeriodCardState();
}

class _PeriodCardState extends State<PeriodCard> {
  bool _pressing = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.showStatus) {
      return _buildPressFeedback(_buildUpcomingCard(context));
    }

    if (widget.isManuallyFinished) {
      return _buildPressFeedback(_buildFinishedCard(context));
    }

    switch (widget.period.status) {
      case PeriodStatus.active:
        return _buildPressFeedback(_buildActiveCard(context));
      case PeriodStatus.finished:
        return _buildPressFeedback(_buildFinishedCard(context));
      case PeriodStatus.upcoming:
        return _buildPressFeedback(_buildUpcomingCard(context));
    }
  }

  Widget _buildPressFeedback(Widget child) {
    final p = widget.period;
    return Semantics(
      label: 'Period ${p.periodNumber}, ${p.subject}, ${p.classroom}, '
          '${p.start} to ${p.end}',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressing = true),
        onTapUp: (_) => setState(() => _pressing = false),
        onTapCancel: () => setState(() => _pressing = false),
        child: AnimatedScale(
          scale: _pressing ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOutCubic,
          child: child,
        ),
      ),
    );
  }

  Widget _buildUpcomingCard(BuildContext context) {
    final colors = context.relColors;
    final countdown = widget.period.minutesUntilStart;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: _cardContent(
        subjectColor: colors.textPrimary,
        secondaryColor: colors.textSecondary,
        badge: widget.isVeryNext && countdown != null && countdown > 0
            ? _countdownBadge(countdown, colors)
            : null,
        strikethrough: false,
        colors: colors,
      ),
    );
  }

  Widget _buildActiveCard(BuildContext context) {
    final colors = context.relColors;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final progress = widget.period.progress;
    final minutesRemaining = widget.period.minutesRemaining;
    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.actionSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.action, width: 2),
      ),
      child: Column(
        children: [
          _cardContent(
            subjectColor: colors.action,
            secondaryColor: colors.action,
            badge: _ongoingBadge(
              reduceMotion: reduceMotion,
              colors: colors,
            ),
            strikethrough: false,
            boldSubject: true,
            colors: colors,
          ),
          if (progress != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    label: 'Period progress ${(progress * 100).round()} percent',
                    child: WavyProgressBar(
                      value: progress,
                      activeColor: colors.action,
                      trackColor: colors.action.withValues(alpha: 0.15),
                      height: 6.0,
                      amplitude: 2.5,
                      wavelength: 26.0,
                      strokeWidth: 2.2,
                      animate: !reduceMotion,
                    ),
                  ),
                ),
                if (minutesRemaining != null) ...[
                  const SizedBox(width: 10),
                  Text(
                    '${Period.formatMinutes(minutesRemaining)} left',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: colors.action,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
    if (reduceMotion) return card;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          card,
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 2,
            child: _EdgeLight(color: colors.action),
          ),
        ],
      ),
    );
  }

  Widget _countdownBadge(int minutes, RelationalColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.actionSubtle,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.action.withValues(alpha: 0.25),
          width: 0.5,
        ),
      ),
      child: Text(
        'in ${Period.formatMinutes(minutes)}',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: colors.action,
        ),
      ),
    );
  }

  Widget _ongoingBadge({
    required bool reduceMotion,
    required RelationalColors colors,
  }) {
    return Semantics(
      label: 'Ongoing',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: colors.action.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            reduceMotion
                ? Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: colors.action,
                      shape: BoxShape.circle,
                    ),
                  )
                : _BreathingDot(color: colors.action),
            const SizedBox(width: 5),
            Text(
              'now',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: colors.action,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinishedCard(BuildContext context) {
    final colors = context.relColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: _cardContent(
        subjectColor: colors.borderMuted,
        secondaryColor: colors.borderMuted,
        badge: _doneBadge(colors: colors),
        strikethrough: true,
        colors: colors,
        isDone: true,
      ),
    );
  }

  Widget _doneBadge({required RelationalColors colors}) {
    return Semantics(
      label: 'Done. Tap to mark as unfinished',
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onToggleFinished != null
            ? () {
                HapticFeedback.lightImpact();
                widget.onToggleFinished!();
              }
            : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.borderSubtle, width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_rounded, size: 12, color: colors.textSecondary),
              const SizedBox(width: 4),
              Text(
                'Done',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _unobtrusiveCheckBtn({required RelationalColors colors}) {
    if (widget.onToggleFinished == null) return const SizedBox.shrink();
    return Semantics(
      label: 'Mark as finished',
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onToggleFinished!();
        },
        child: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.borderSubtle.withValues(alpha: 0.12),
                border: Border.all(
                  color: colors.borderSubtle,
                  width: 1.2,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.check_rounded,
                size: 13,
                color: colors.borderMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _cardContent({
    required Color subjectColor,
    required Color secondaryColor,
    required Widget? badge,
    required bool strikethrough,
    required RelationalColors colors,
    bool isDone = false,
    bool boldSubject = false,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: secondaryColor.withValues(alpha: 0.1),
            borderRadius: PeriodVisuals.borderRadius(widget.period.periodNumber),
          ),
          child: Text(
            '${widget.period.periodNumber}',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: secondaryColor,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.period.subject,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 20,
                  fontWeight: boldSubject ? FontWeight.w700 : FontWeight.w600,
                  color: subjectColor,
                  decoration: strikethrough ? TextDecoration.lineThrough : null,
                  decorationColor: subjectColor,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: secondaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: secondaryColor.withValues(alpha: 0.15),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 11,
                          color: secondaryColor,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          widget.period.classroom,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: secondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${widget.period.start} – ${widget.period.end}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'PlayfairDisplay',
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: secondaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (badge != null) badge,
        if (widget.onToggleFinished != null && !isDone)
          _unobtrusiveCheckBtn(colors: colors),
      ],
    );
  }
}

class _EdgeLight extends StatefulWidget {
  final Color color;
  const _EdgeLight({required this.color});

  @override
  State<_EdgeLight> createState() => _EdgeLightState();
}

class _EdgeLightState extends State<_EdgeLight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final x = -0.3 + (_controller.value * 1.6);
        return FractionallySizedBox(
          widthFactor: 0.3,
          alignment: Alignment(x, 0),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  widget.color.withValues(alpha: 0),
                  widget.color.withValues(alpha: 0.5),
                  widget.color.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BreathingDot extends StatefulWidget {
  final Color color;
  const _BreathingDot({required this.color});

  @override
  State<_BreathingDot> createState() => _BreathingDotState();
}

class _BreathingDotState extends State<_BreathingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final glow = 2.0 + (_controller.value * 4.0);
        return Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.4),
                blurRadius: glow,
              ),
            ],
          ),
        );
      },
    );
  }
}
