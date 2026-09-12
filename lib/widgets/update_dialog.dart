import 'package:flutter/material.dart';

import '../services/update_service.dart';
import '../theme/relational_colors.dart';
import 'app_feedback.dart';

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
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  int _receivedBytes = 0;
  int _totalBytes = 0;
  bool _downloadCancelled = false;
  String? _downloadError;
  String? _downloadedFilePath;
  String _activeArchLabel = '';

  @override
  void initState() {
    super.initState();
    _detectArchitecture();
  }

  Future<void> _detectArchitecture() async {
    final arch = await UpdateService.getDeviceArchitecture();
    if (mounted) {
      setState(() {
        _detectedArch = arch;
        _detecting = false;
      });
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _startDirectDownload(String downloadUrl, String archLabel) async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _receivedBytes = 0;
      _totalBytes = 0;
      _downloadError = null;
      _downloadCancelled = false;
      _downloadedFilePath = null;
      _activeArchLabel = archLabel;
    });

    final fileName = 'jadwal-${widget.release.tagName}-$archLabel.apk';

    try {
      final filePath = await UpdateService.downloadApkDirectly(
        url: downloadUrl,
        fileName: fileName,
        onProgress: (received, total, progress) {
          if (mounted && !_downloadCancelled) {
            setState(() {
              _receivedBytes = received;
              _totalBytes = total;
              _downloadProgress = progress;
            });
          }
        },
        isCancelled: () => _downloadCancelled,
      );

      if (mounted && !_downloadCancelled) {
        setState(() {
          _isDownloading = false;
          _downloadedFilePath = filePath;
        });

        // Automatically prompt the Android system installer
        final launched = await UpdateService.installApk(filePath);
        if (!launched && mounted) {
          final canInstall = await UpdateService.canInstallUnknownApps();
          if (!canInstall) {
            setState(() {
              _downloadError =
                  'Permission required: Please enable "Install unknown apps" for Jadwal in Settings to update.';
            });
            await UpdateService.openInstallUnknownAppsSettings();
          }
        }
      }
    } catch (e) {
      if (mounted && !_downloadCancelled) {
        setState(() {
          _isDownloading = false;
          _downloadError =
              'Direct download failed. You can retry, download in background, or open the release page.';
        });
      }
    }
  }

  void _cancelDownload() {
    setState(() {
      _downloadCancelled = true;
      _isDownloading = false;
    });
  }

  Future<void> _downloadInBackground(String downloadUrl, String archLabel) async {
    final fileName = 'jadwal-${widget.release.tagName}-$archLabel.apk';
    final title = 'Jadwal ${widget.release.tagName} ($archLabel)';

    setState(() {
      _downloadCancelled = true;
      _isDownloading = false;
    });

    await UpdateService.downloadWithDownloadManager(
      url: downloadUrl,
      fileName: fileName,
      title: title,
    );

    if (mounted) {
      Navigator.of(context).pop();
      AppFeedback.showInfo(
        context,
        'Downloading in background... Check notification bar.',
      );
    }
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
                      const SizedBox(height: 4),
                      Text(
                        'Jadwal ${release.tagName}',
                        style: TextStyle(
                          fontFamily: 'Geist',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'A newer version is ready to install',
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
                          fontFamily: 'Geist',
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
                                      fontFamily: 'Geist',
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
                      fontFamily: 'Geist',
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
                      fontFamily: 'Geist',
                      fontSize: 11.5,
                      height: 1.35,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Dynamic Action Area: Downloading / Ready to Install / Idle Buttons
            if (_isDownloading) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.surfaceContainer,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.borderSubtle, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            value: _downloadProgress > 0 ? _downloadProgress : null,
                            color: colors.action,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Downloading update (${_activeArchLabel.toUpperCase()})...',
                            style: TextStyle(
                              fontFamily: 'Geist',
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          _downloadProgress > 0
                              ? '${(_downloadProgress * 100).toInt()}%'
                              : 'Connecting...',
                          style: TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colors.action,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _downloadProgress > 0 ? _downloadProgress : null,
                        color: colors.action,
                        backgroundColor: colors.borderSubtle,
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _totalBytes > 0
                              ? '${_formatBytes(_receivedBytes)} / ${_formatBytes(_totalBytes)}'
                              : _formatBytes(_receivedBytes),
                          style: TextStyle(
                            fontFamily: 'Geist',
                            fontSize: 11.5,
                            color: colors.textSecondary,
                          ),
                        ),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () => _downloadInBackground(
                                targetDownloadUrl,
                                archLabel,
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Background',
                                style: TextStyle(
                                  fontFamily: 'Geist',
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: colors.action,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: _cancelDownload,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  fontFamily: 'Geist',
                                  fontSize: 11.5,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ] else if (_downloadedFilePath != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.surfaceContainer,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.borderSubtle, width: 1),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 20,
                          color: colors.action,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Update downloaded and ready',
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
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => UpdateService.installApk(_downloadedFilePath!),
                      icon: Icon(
                        Icons.install_mobile_rounded,
                        size: 18,
                        color: colors.onAction,
                      ),
                      label: Text(
                        'Install Update Now',
                        style: TextStyle(
                          fontFamily: 'Geist',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: colors.onAction,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.action,
                        minimumSize: const Size.fromHeight(42),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Done',
                    style: TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 12.5,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ),
            ] else ...[
              if (_downloadError != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainer,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colors.borderSubtle),
                  ),
                  child: Text(
                    _downloadError!,
                    style: TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 11.5,
                      height: 1.3,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ],

              // Primary Direct Download Button (Auto-matched to device ABI)
              FilledButton.icon(
                onPressed: () => _startDirectDownload(targetDownloadUrl, archLabel),
                icon: Icon(
                  Icons.download_rounded,
                  size: 19,
                  color: colors.onAction,
                ),
                label: Text(
                  'Download Update ($archLabel APK)',
                  style: TextStyle(
                    fontFamily: 'Geist',
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
                  onPressed: () => _startDirectDownload(otherDownloadUrl, otherLabel),
                  icon: Icon(
                    Icons.download_rounded,
                    size: 17,
                    color: colors.textPrimary,
                  ),
                  label: Text(
                    'Download alternate ($otherLabel APK)',
                    style: TextStyle(
                      fontFamily: 'Geist',
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
                        fontFamily: 'Geist',
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
                        fontFamily: 'Geist',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
