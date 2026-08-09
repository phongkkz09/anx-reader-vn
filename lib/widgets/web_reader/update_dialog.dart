import 'package:flutter/material.dart';
import 'package:anx_reader/service/web_reader/auto_updater.dart';

/// Check Update Button Widget
/// Shows in Settings or About screen
class CheckUpdateButton extends StatefulWidget {
  const CheckUpdateButton({super.key});

  @override
  State<CheckUpdateButton> createState() => _CheckUpdateButtonState();
}

class _CheckUpdateButtonState extends State<CheckUpdateButton> {
  final AutoUpdater _updater = AutoUpdater();
  bool _isChecking = false;
  String? _lastCheckTime;

  @override
  void initState() {
    super.initState();
    _loadLastCheckTime();
  }

  void _loadLastCheckTime() {
    // Will be loaded from prefs in checkForUpdate
  }

  Future<void> _checkUpdate() async {
    if (_isChecking) return;

    setState(() => _isChecking = true);

    try {
      final version = await _updater.checkForUpdate();

      if (!mounted) return;

      if (version != null) {
        await AutoUpdater.showUpdateDialog(context, version, _updater);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bạn đang dùng phiên bản mới nhất (${_updater.currentVersion})'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi kiểm tra cập nhật: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.system_update),
      title: const Text('Kiểm tra cập nhật'),
      subtitle: Text('Phiên bản hiện tại: ${_updater.currentVersion}'),
      trailing: _isChecking
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.chevron_right),
      onTap: _isChecking ? null : _checkUpdate,
    );
  }
}

/// About App Dialog with update check
class AboutAppDialog extends StatelessWidget {
  const AboutAppDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const AboutAppDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Image.asset(
            'assets/images/icon.png',
            width: 48,
            height: 48,
            errorBuilder: (_, __, ___) => const Icon(Icons.book, size: 48),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Text('Anx Reader VN')),
        ],
      ),
      content: const SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Phiên bản: 1.15.0'),
            SizedBox(height: 8),
            Text('Ứng dụng đọc truyện với AI & TTS'),
            SizedBox(height: 12),
            Text('Tính năng:'),
            SizedBox(height: 4),
            Text('• Web Reader — nghe truyện từ website'),
            Text('• Download Manager — tải & quản lý'),
            Text('• Library — theo dõi truyện yêu thích'),
            Text('• AI Providers — cấu hình AI (OpenAI, Gemini...)'),
            Text('• TTS Backends — chọn giọng đọc'),
            Text('• Extension Sources — thêm nguồn truyện'),
            SizedBox(height: 16),
            Text('Phát triển bởi: phongkkz09'),
            Text('Github: phongkkz09/anx-reader-vn'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Đóng'),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.pop(context);
            _checkUpdateFromDialog(context);
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Kiểm tra cập nhật'),
        ),
      ],
    );
  }

  void _checkUpdateFromDialog(BuildContext context) async {
    final updater = AutoUpdater();
    final version = await updater.checkForUpdate();

    if (context.mounted) {
      if (version != null) {
        await AutoUpdater.showUpdateDialog(context, version, updater);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bạn đang dùng phiên bản mới nhất (${updater.currentVersion})'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}
