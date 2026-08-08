import 'package:flutter/material.dart';
import 'package:anx_reader/service/web_reader/web_reader_settings.dart';

/// Settings bottom sheet for Web Reader
/// Includes: sleep timer, playback speed, pronunciation dictionary
class WebReaderSettingsSheet extends StatefulWidget {
  final WebReaderSettings settings;
  final VoidCallback onSettingsChanged;

  const WebReaderSettingsSheet({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
  });

  @override
  State<WebReaderSettingsSheet> createState() => _WebReaderSettingsSheetState();

  /// Show the settings sheet
  static Future<void> show(
    BuildContext context, {
    required WebReaderSettings settings,
    required VoidCallback onSettingsChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => WebReaderSettingsSheet(
        settings: settings,
        onSettingsChanged: onSettingsChanged,
      ),
    );
  }
}

class _WebReaderSettingsSheetState extends State<WebReaderSettingsSheet> {
  late double _speed;
  late bool _sleepActive;

  @override
  void initState() {
    super.initState();
    _speed = widget.settings.playbackSpeed;
    _sleepActive = widget.settings.isSleepTimerActive;
  }

  void _notifyChanged() {
    widget.onSettingsChanged();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Cài đặt nghe truyện',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 16),
            // Playback Speed
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(Icons.speed),
                  const SizedBox(width: 12),
                  const Text('Tốc độ phát:'),
                  const Spacer(),
                  Text(
                    '${_speed.toStringAsFixed(1)}x',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      widget.settings
                          .setPlaybackSpeed((_speed - 0.1).clamp(0.5, 4.0));
                      _speed = widget.settings.playbackSpeed;
                      _notifyChanged();
                    },
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Expanded(
                    child: Slider(
                      value: _speed,
                      min: 0.5,
                      max: 4.0,
                      divisions: 35,
                      label: '${_speed.toStringAsFixed(1)}x',
                      onChanged: (value) {
                        widget.settings.setPlaybackSpeed(value);
                        _speed = value;
                        _notifyChanged();
                      },
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      widget.settings
                          .setPlaybackSpeed((_speed + 0.1).clamp(0.5, 4.0));
                      _speed = widget.settings.playbackSpeed;
                      _notifyChanged();
                    },
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
            ),
            const Divider(),
            // Sleep Timer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(Icons.bedtime),
                  const SizedBox(width: 12),
                  const Text('Hẹn giờ tắt'),
                  const Spacer(),
                  if (_sleepActive)
                    TextButton(
                      onPressed: () {
                        widget.settings.cancelSleepTimer();
                        _sleepActive = false;
                        _notifyChanged();
                      },
                      child: const Text('Hủy'),
                    ),
                  if (!_sleepActive)
                    TextButton(
                      onPressed: () => _showSleepTimerOptions(),
                      child: const Text('Đặt'),
                    ),
                ],
              ),
            ),
            // Sleep timer status
            if (_sleepActive)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  _getSleepStatusText(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 13,
                  ),
                ),
              ),
            const Divider(),
            // Pronunciation Dictionary
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(Icons.translate),
                  const SizedBox(width: 12),
                  const Text('Bộ sửa từ đọc'),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _showPronunciationEditor(),
                    child: Text(
                      'Sửa (${widget.settings.pronunciations.length})',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _getSleepStatusText() {
    final settings = widget.settings;
    final time = settings.remainingSleepTime;
    if (time != null) {
      final minutes = time.inMinutes;
      final seconds = time.inSeconds % 60;
      return 'Sẽ tắt sau ${minutes}m ${seconds}s';
    }
    if (settings.remainingChapters > 0) {
      return 'Sẽ tắt sau ${settings.remainingChapters} chương nữa';
    }
    return 'Đang đếm ngược...';
  }

  void _showSleepTimerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('10 phút'),
              leading: const Icon(Icons.timer),
              onTap: () {
                widget.settings
                    .startSleepTimer(const Duration(minutes: 10));
                Navigator.pop(context);
                _sleepActive = true;
                _notifyChanged();
              },
            ),
            ListTile(
              title: const Text('30 phút'),
              leading: const Icon(Icons.timer),
              onTap: () {
                widget.settings
                    .startSleepTimer(const Duration(minutes: 30));
                Navigator.pop(context);
                _sleepActive = true;
                _notifyChanged();
              },
            ),
            ListTile(
              title: const Text('60 phút'),
              leading: const Icon(Icons.timer),
              onTap: () {
                widget.settings
                    .startSleepTimer(const Duration(hours: 1));
                Navigator.pop(context);
                _sleepActive = true;
                _notifyChanged();
              },
            ),
            ListTile(
              title: const Text('Hết chương này'),
              leading: const Icon(Icons.book_outlined),
              onTap: () {
                widget.settings.startSleepTimerAfterChapters(1);
                Navigator.pop(context);
                _sleepActive = true;
                _notifyChanged();
              },
            ),
            ListTile(
              title: const Text('Sau 3 chương'),
              leading: const Icon(Icons.menu_book),
              onTap: () {
                widget.settings.startSleepTimerAfterChapters(3);
                Navigator.pop(context);
                _sleepActive = true;
                _notifyChanged();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPronunciationEditor() {
    final controller = TextEditingController();
    final replacementController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Bộ sửa từ đọc',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              // Existing entries
              if (widget.settings.pronunciations.isNotEmpty)
                ...widget.settings.pronunciations.map((entry) {
                  return ListTile(
                    dense: true,
                    title: Text(
                      '${entry.original} → ${entry.replacement}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () {
                        widget.settings.removePronunciation(entry.original);
                        Navigator.pop(context);
                        _showPronunciationEditor();
                        _notifyChanged();
                      },
                    ),
                  );
                }),
              // Add new entry
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        labelText: 'Từ gốc (vd: nv)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: replacementController,
                      decoration: const InputDecoration(
                        labelText: 'Cách đọc (vd: nhân vật)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final original = controller.text.trim();
                          final replacement =
                              replacementController.text.trim();
                          if (original.isNotEmpty &&
                              replacement.isNotEmpty) {
                            widget.settings.addPronunciation(
                                original, replacement);
                            Navigator.pop(context);
                            _showPronunciationEditor();
                            _notifyChanged();
                          }
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Thêm'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
