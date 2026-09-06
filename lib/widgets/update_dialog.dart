import 'package:flutter/material.dart';

import '../services/update_service.dart';
import '../theme/relational_colors.dart';

/// A calm, refined modal dialog displaying the latest release changelog
/// and architecture-aware direct download actions matching Jadwal's "Quiet Companion" design.
class UpdateDialog extends StatefulWidget {
  final AppReleaseInfo release;

  const UpdateDialog({
    super.key,
    required this.release,
  });

  /// Displays the update dialog.
  static Future<void> show(BuildContext context, AppReleaseInfo release) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => UpdateDialog(release: release),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  String _detectedArch = 'arm64';
  bool _detecting = true;
  String? _preResolvedUrl;

  @override
  void initState() {
    super.initState();
    _detectArchitectureAndPreResolve();
  }

  Future<void> _detectArchitectureAndPreResolve() async {
    final arch = await UpdateService.getDeviceArchitecture();
    if (mounted) {
      setState(() {
        _detectedArch = arch;
        _detecting = false;
      });
    }
    try {
      final targetUrl = widget.release.getDownloadUrlForArch(arch);
      final direct = await UpdateService.resolveDirectDownloadUrl(targetUrl);
      if (mounted) {
        _preResolvedUrl = direct;
      }
    } catch (_) {}
  }

  Future<void> _startDownload(BuildContext context, String fallbackUrl) async {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Starting download...',
          style: TextStyle(fontFamily: 'Inter'),
        ),
        duration: Duration(seconds: 2),
      ),
    );
    final finalUrl = (fallbackUrl == widget.release.getDownloadUrlForArch(_detectedArch) &&
            _preResolvedUrl != null)
        ? _preResolvedUrl!
        : await UpdateService.resolveDirectDownloadUrl(fallbackUrl);
    await UpdateService.openUrl(finalUrl);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.relColors;
    final release = widget.release;

    final targetDownloadUrl = release.getDownloadUrlForArch(_detectedArch);
    final otherArch = _detectedArch == 'arm64' ? 'arm32' : 'arm64';
    final otherDownloadUrl = release.getDownloadUrlForArch(otherArch);
    final hasAlternate = otherDownloadUrl != targetDownloadUrl;

    final archLabel = _detectedArch == 'arm64' ? '64-bit' : '32-bit';
    final otherLabel = otherArch == 'arm64' ? '64-bit' : '32-bit';

    return Dialog(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colors.borderSubtle, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Badge & Title Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colors.actionSubtle,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.system_update_rounded,
                    color: colors.action,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.actionSubtle,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'UPDATE AVAILABLE',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: colors.action,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Jadwal ${release.tagName}',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'A newer version is ready to install',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12.5,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Styled Changelog Box
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surfaceContainer,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.borderSubtle, width: 1),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 14,
                        color: colors.action,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "WHAT'S NEW",
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Flexible(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: release.changelogBullets.map((bullet) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 5,
                                  height: 5,
                                  margin: const EdgeInsets.only(
                                    top: 7,
                                    right: 9,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.action,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    bullet,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12.5,
                                      height: 1.35,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Device Architecture Detection Notice
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  _detecting
                      ? Icons.hourglass_top_rounded
                      : Icons.check_circle_outline_rounded,
                  size: 14,
                  color: colors.action,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    _detecting
                      ? 'Detecting device architecture...'
                      : 'Detected $archLabel architecture for your device.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Simple installation hint
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Tap download to save the matching APK, then open it to install.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11.5,
                      height: 1.35,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Primary Direct Download Button (Auto-matched to device ABI)
            FilledButton.icon(
              onPressed: () => _startDownload(context, targetDownloadUrl),
              icon: Icon(
                Icons.download_rounded,
                size: 19,
                color: colors.onAction,
              ),
              label: Text(
                'Download Update ($archLabel APK)',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.onAction,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: colors.action,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            // Alternate architecture download button if available
            if (hasAlternate) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _startDownload(context, otherDownloadUrl),
                icon: Icon(
                  Icons.download_rounded,
                  size: 17,
                  color: colors.textPrimary,
                ),
                label: Text(
                  'Download alternate ($otherLabel APK)',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: colors.textPrimary,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: colors.borderSubtle, width: 1),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 6),

            // Bottom row: Release page link & Later
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    UpdateService.openUrl(release.htmlUrl);
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Release page',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: colors.textSecondary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Later',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
