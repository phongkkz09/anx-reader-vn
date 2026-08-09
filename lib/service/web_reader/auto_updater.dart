import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:anx_reader/config/shared_preference_provider.dart';

/// Version info from GitHub Releases
class AppVersion {
  final String version;      // e.g. "1.16.0"
  final String tagName;      // e.g. "v1.16.0"
  final String downloadUrl;  // APK download URL
  final String releaseNotes; // Markdown release notes
  final DateTime publishedAt;
  final int sizeBytes;
  final bool isPrerelease;

  const AppVersion({
    required this.version,
    required this.tagName,
    required this.downloadUrl,
    this.releaseNotes = '',
    required this.publishedAt,
    this.sizeBytes = 0,
    this.isPrerelease = false,
  });

  factory AppVersion.fromGithubRelease(Map<String, dynamic> json) {
    String? apkUrl;
    int size = 0;

    // Find APK asset
    final assets = json['assets'] as List? ?? [];
    for (final asset in assets) {
      final name = asset['name'] as String? ?? '';
      if (name.endsWith('.apk') && !name.contains('debug')) {
        apkUrl = asset['browser_download_url'] as String?;
        size = (asset['size'] as int?) ?? 0;
        break;
      }
    }

    // Fallback to first APK if no release APK
    if (apkUrl == null) {
      for (final asset in assets) {
        final name = asset['name'] as String? ?? '';
        if (name.endsWith('.apk')) {
          apkUrl = asset['browser_download_url'] as String?;
          size = (asset['size'] as int?) ?? 0;
          break;
        }
      }
    }

    return AppVersion(
      version: (json['tag_name'] as String?)?.replaceFirst('v', '') ?? '0.0.0',
      tagName: json['tag_name'] as String? ?? '',
      downloadUrl: apkUrl ?? '',
      releaseNotes: json['body'] as String? ?? '',
      publishedAt: DateTime.tryParse(json['published_at'] ?? '') ?? DateTime.now(),
      sizeBytes: size,
      isPrerelease: json['prerelease'] as bool? ?? false,
    );
  }
}

/// Download progress callback
typedef DownloadProgressCallback = void Function(int received, int total, double percentage);

/// Auto-updater service
/// Checks GitHub Releases for new versions and downloads/installs APK
class AutoUpdater {
  static final AutoUpdater _instance = AutoUpdater._internal();
  factory AutoUpdater() => _instance;
  AutoUpdater._internal();

  static const String _repoOwner = 'phongkkz09';
  static const String _repoName = 'anx-reader-vn';
  static const String _currentVersion = '1.15.0'; // From pubspec.yaml

  static const String _lastCheckKey = 'auto_update_last_check';
  static const String _skipVersionKey = 'auto_update_skip_version';

  final Dio _dio = Dio();

  /// Check for updates (returns null if no update available)
  Future<AppVersion?> checkForUpdate({
    bool includePrerelease = false,
  }) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        'https://api.github.com/repos/$_repoOwner/$_repoName/releases',
        options: Options(
          headers: {'Accept': 'application/vnd.github.v3+json'},
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      final releases = response.data ?? [];
      for (final release in releases) {
        final version = AppVersion.fromGithubRelease(release);

        // Skip prereleases unless requested
        if (version.isPrerelease && !includePrerelease) continue;

        // Skip if version is skipped by user
        if (version.version == _getSkippedVersion()) continue;

        // Check if newer than current
        if (_isNewerVersion(version.version, _currentVersion)) {
          return version;
        }
      }

      // Update last check time
      Prefs().prefs.setString(_lastCheckKey, DateTime.now().toIso8601String());

      return null;
    } catch (e) {
      debugPrint('AutoUpdater.checkForUpdate error: $e');
      return null;
    }
  }

  /// Download APK with progress
  Future<String?> downloadApk(
    AppVersion version, {
    DownloadProgressCallback? onProgress,
  }) async {
    if (version.downloadUrl.isEmpty) {
      debugPrint('AutoUpdater.downloadApk: no download URL');
      return null;
    }

    try {
      // Get download directory
      final dir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
      final fileName = 'anx-reader-${version.version}.apk';
      final filePath = '${dir.path}/$fileName';

      // Delete old APK if exists
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }

      // Download with progress
      await _dio.download(
        version.downloadUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total > 0 && onProgress != null) {
            onProgress(received, total, (received / total) * 100);
          }
        },
        options: Options(
          receiveTimeout: const Duration(minutes: 10),
          sendTimeout: const Duration(minutes: 10),
        ),
      );

      return filePath;
    } catch (e) {
      debugPrint('AutoUpdater.downloadApk error: $e');
      return null;
    }
  }

  /// Install APK (opens system installer)
  Future<bool> installApk(String filePath) async {
    try {
      final result = await OpenFile.open(
        filePath,
        type: 'application/vnd.android.package-archive',
      );

      return result.type == ResultType.done;
    } catch (e) {
      debugPrint('AutoUpdater.installApk error: $e');
      return false;
    }
  }

  /// Check if automatic update check should run
  bool shouldAutoCheck({Duration interval = const Duration(hours: 24)}) {
    final lastCheckStr = Prefs().prefs.getString(_lastCheckKey);
    if (lastCheckStr == null) return true;

    final lastCheck = DateTime.tryParse(lastCheckStr);
    if (lastCheck == null) return true;

    return DateTime.now().difference(lastCheck) >= interval;
  }

  /// Skip this version (user chose "remind me later")
  void skipVersion(String version) {
    Prefs().prefs.setString(_skipVersionKey, version);
  }

  /// Get skipped version
  String _getSkippedVersion() {
    return Prefs().prefs.getString(_skipVersionKey) ?? '';
  }

  /// Clear skipped version
  void clearSkippedVersion() {
    Prefs().prefs.remove(_skipVersionKey);
  }

  /// Get current version
  String get currentVersion => _currentVersion;

  /// Get GitHub releases URL
  String get releasesUrl => 'https://github.com/$_repoOwner/$_repoName/releases';

  /// Compare versions (returns true if remote > current)
  bool _isNewerVersion(String remote, String current) {
    try {
      final r = remote.split('.').map((s) => int.tryParse(s) ?? 0).toList();
      final c = current.split('.').map((s) => int.tryParse(s) ?? 0).toList();

      // Pad to same length
      while (r.length < 3) r.add(0);
      while (c.length < 3) c.add(0);

      for (int i = 0; i < 3; i++) {
        if (r[i] > c[i]) return true;
        if (r[i] < c[i]) return false;
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  /// Show update dialog
  static Future<void> showUpdateDialog(
    BuildContext context,
    AppVersion version,
    AutoUpdater updater,
  ) async {
    final sizeMB = (version.sizeBytes / 1024 / 1024).toStringAsFixed(1);

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.system_update, color: Colors.green),
            const SizedBox(width: 12),
            Text('Cập nhật ${version.version}'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Phiên bản mới: ${version.version}'),
              Text('Phiên bản hiện tại: ${updater.currentVersion}'),
              Text('Kích thước: $sizeMB MB'),
              const SizedBox(height: 12),
              if (version.releaseNotes.isNotEmpty) ...[
                const Text('Thay đổi:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    version.releaseNotes,
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              updater.skipVersion(version.version);
              Navigator.pop(context);
            },
            child: const Text('Bỏ qua phiên bản này'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Để sau'),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _downloadAndInstall(context, version, updater);
            },
            icon: const Icon(Icons.download),
            label: const Text('Tải & cài đặt'),
          ),
        ],
      ),
    );
  }

  /// Download and install with progress dialog
  static Future<void> _downloadAndInstall(
    BuildContext context,
    AppVersion version,
    AutoUpdater updater,
  ) async {
    String? filePath;
    double progress = 0;

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Đang tải cập nhật...'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(value: progress / 100),
              const SizedBox(height: 12),
              Text('${progress.toStringAsFixed(0)}%'),
            ],
          ),
        ),
      ),
    );

    try {
      filePath = await updater.downloadApk(
        version,
        onProgress: (received, total, percent) {
          progress = percent;
          // Update dialog (can't easily update, so we continue)
        },
      );

      Navigator.pop(context); // Close progress dialog

      if (filePath != null) {
        final installed = await updater.installApk(filePath);
        if (!installed && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không thể mở file APK. Vui lòng cài thủ công.')),
          );
        }
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tải xuống thất bại. Vui lòng thử lại.')),
        );
      }
    } catch (e) {
      Navigator.pop(context); // Close progress dialog
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }
}
