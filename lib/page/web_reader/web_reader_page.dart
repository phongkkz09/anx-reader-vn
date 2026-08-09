import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anx_reader/providers/web_reader_provider.dart';
import 'package:anx_reader/service/tts/tts_factory.dart';
import 'package:anx_reader/service/tts/base_tts.dart';
import 'package:anx_reader/service/tts/tts_service.dart';
import 'package:anx_reader/service/web_reader/web_reader_settings.dart';
import 'package:anx_reader/service/web_reader/extensions/extension_registry.dart';
import 'package:anx_reader/service/web_reader/web_reader_handler.dart';
import 'package:anx_reader/service/web_reader/web_content_extractor.dart';
import 'package:anx_reader/service/web_reader/download_manager.dart';
import 'package:anx_reader/service/web_reader/web_novel_library.dart';
import 'package:anx_reader/page/web_reader/web_novel_library_page.dart';
import 'package:anx_reader/widgets/web_reader/web_reader_settings_sheet.dart';
import 'package:anx_reader/widgets/web_reader/extension_manager_dialog.dart';
import 'package:anx_reader/widgets/web_reader/download_manager_sheet.dart';
import 'package:anx_reader/widgets/web_reader/provider_config_dialog.dart';
import 'package:anx_reader/widgets/web_reader/update_dialog.dart';
import 'package:anx_reader/widgets/web_reader/export_dialog.dart';

class WebReaderPage extends ConsumerStatefulWidget {
  const WebReaderPage({Key? key}) : super(key: key);

  @override
  ConsumerState<WebReaderPage> createState() => _WebReaderPageState();
}

class _WebReaderPageState extends ConsumerState<WebReaderPage> {
  final _urlController = TextEditingController();
  final _settings = WebReaderSettings();
  final _extensionRegistry = ExtensionRegistry();
  final _audioHandler = WebReaderHandler();
  final _downloadManager = DownloadManager();
  late BaseTts _tts;
  bool _ttsInitialized = false;
  String? _sleepTimerDisplay;

  @override
  void initState() {
    super.initState();
    _initTts();
    _initSleepTimer();
  }

  void _initSleepTimer() {
    _settings.addSleepTimerListener(() {
      _audioHandler.stop();
      ref.read(webReaderProvider.notifier).setPlaying(false);
      setState(() {
        _sleepTimerDisplay = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hẹn giờ đã kết thúc')),
        );
      }
    });
  }

  Future<void> _initTts() async {
    _tts = TtsFactory().current;
    await _audioHandler.init(
      getCurrentText: () async => ref.read(webReaderProvider).content?.content ?? '',
      getNextText: () async => ref.read(webReaderProvider).content?.content ?? '',
      getPrevText: () async => '',
      onNextChapter: () {
        ref.read(webReaderProvider.notifier).loadNextChapter();
        Future.delayed(const Duration(milliseconds: 300), _speakCurrentContent);
      },
      onPrevChapter: () {
        ref.read(webReaderProvider.notifier).loadPrevChapter();
        Future.delayed(const Duration(milliseconds: 300), _speakCurrentContent);
      },
      onStop: () {
        ref.read(webReaderProvider.notifier).setPlaying(false);
      },
    );
    _ttsInitialized = true;
  }

  @override
  void dispose() {
    _urlController.dispose();
    _settings.removeSleepTimerListener(() {});
    super.dispose();
  }

  void _loadUrl() {
    final url = _urlController.text.trim();
    if (url.isNotEmpty) {
      ref.read(webReaderProvider.notifier).loadContent(url);
    }
  }

  Future<void> _togglePlayPause() async {
    final notifier = ref.read(webReaderProvider.notifier);
    final state = ref.read(webReaderProvider);

    if (state.isPlaying) {
      await _audioHandler.pause();
      notifier.setPlaying(false);
    } else {
      if (state.content?.content.isNotEmpty ?? false) {
        _audioHandler.setMetadata(
          title: state.content!.title,
          url: state.content!.url,
        );
        await _audioHandler.play();
        notifier.setPlaying(true);
      }
    }
  }

  void _listenForCompletion() {
    // Now handled by WebReaderHandler - no manual listener needed
  }

  void _onTtsStateChange() {
    // Now handled by WebReaderHandler - no manual listener needed
  }

  Future<void> _speakCurrentContent() async {
    final state = ref.read(webReaderProvider);
    if (state.content?.content.isNotEmpty ?? false) {
      _audioHandler.setMetadata(
        title: state.content!.title,
        url: state.content!.url,
      );
      await _audioHandler.play();
    }
  }

  void _nextChapter() {
    ref.read(webReaderProvider.notifier).loadNextChapter();
    if (ref.read(webReaderProvider).isPlaying) {
      _audioHandler.setMetadata(
        title: ref.read(webReaderProvider).content?.title ?? 'Next',
        url: ref.read(webReaderProvider).content?.nextChapterUrl ?? '',
      );
      Future.delayed(const Duration(milliseconds: 300), _speakCurrentContent);
    }
  }

  void _prevChapter() {
    ref.read(webReaderProvider.notifier).loadPrevChapter();
    if (ref.read(webReaderProvider).isPlaying) {
      _audioHandler.setMetadata(
        title: ref.read(webReaderProvider).content?.title ?? 'Prev',
        url: ref.read(webReaderProvider).content?.prevChapterUrl ?? '',
      );
      Future.delayed(const Duration(milliseconds: 300), _speakCurrentContent);
    }
  }

  void _showChapterList() {
    ref.read(webReaderProvider.notifier).toggleChapterList();
  }

  void _showExportDialog(WebContent content) {
    ExportDialog.show(
      context: context,
      novelTitle: content.title,
      novelAuthor: 'Unknown',
      chapters: content.chapters,
      fetchChapterContent: (url) async {
        // Fetch chapter content using WebContentExtractor
        final extractor = WebContentExtractor();
        final chapterContent = await extractor.extractContent(url);
        return chapterContent.content;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(webReaderProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nghe truyện từ Web'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.psychology),
            onPressed: () {
              ProviderConfigDialog.show(context);
            },
            tooltip: 'Cấu hình AI/TTS',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () {
              DownloadManagerSheet.show(context);
            },
            tooltip: 'Tải xuống',
          ),
          IconButton(
            icon: const Icon(Icons.extension),
            onPressed: () {
              ExtensionManagerDialog.show(context);
            },
            tooltip: 'Nguồn truyện',
          ),
          IconButton(
            icon: const Icon(Icons.system_update),
            onPressed: () {
              AboutAppDialog.show(context);
            },
            tooltip: 'Về ứng dụng',
          ),
          if (state.content != null && state.content!.chapters.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.file_download),
              onPressed: () => _showExportDialog(state.content!),
              tooltip: 'Xuất file',
            ),
            IconButton(
              icon: const Icon(Icons.list_alt),
              onPressed: _showChapterList,
              tooltip: 'Danh sách chương (${state.content!.chapters.length})',
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // URL Input Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dán link truyện:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _urlController,
                        decoration: InputDecoration(
                          hintText: 'https://example.com/story/chapter-1',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onSubmitted: (_) => _loadUrl(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: state.isLoading ? null : _loadUrl,
                      icon: state.isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.download),
                      label: const Text('Tải'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Error Display
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: Colors.red.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        state.error!,
                        style: TextStyle(color: Colors.red.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Content Display
          if (state.content != null)
            Expanded(
              child: Column(
                children: [
                  // Content Title + Chapter Info
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.grey.shade100,
                    child: Column(
                      children: [
                        Text(
                          state.content!.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (state.chapterInfo.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Chương ${state.chapterInfo}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Content Text
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        state.content!.content,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Controls Section
          if (state.content != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Column(
                children: [
                  // Chapter Navigation
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton.filled(
                        onPressed: (state.content?.hasPrevChapter ?? false) &&
                                !state.isLoading
                            ? _prevChapter
                            : null,
                        icon: const Icon(Icons.skip_previous),
                        tooltip: 'Chương trước',
                      ),
                      // Playback Controls
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton.filled(
                            onPressed: state.isLoading ? null : _togglePlayPause,
                            icon: Icon(
                              state.isPlaying ? Icons.pause : Icons.play_arrow,
                            ),
                            tooltip: state.isPlaying ? 'Tạm dừng' : 'Phát',
                          ),
                          const SizedBox(width: 16),
                          if (state.content?.hasNextChapter ?? false)
                            IconButton.filled(
                              onPressed: state.isLoading ? null : _nextChapter,
                              icon: const Icon(Icons.skip_next),
                              tooltip: 'Chương tiếp theo',
                            ),
                        ],
                      ),
                      const SizedBox(width: 48), // Balance
                    ],
                  ),
                  const SizedBox(height: 12),
                  // TTS Settings Button
                  ElevatedButton.icon(
                    onPressed: () {
                      _addToLibrary(state.content!.title);
                    },
                    icon: const Icon(Icons.library_add),
                    label: const Text('Thêm vào thư viện'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      WebReaderSettingsSheet.show(
                        context,
                        settings: _settings,
                        onSettingsChanged: () {
                          setState(() {});
                        },
                      );
                    },
                    icon: const Icon(Icons.settings),
                    label: const Text('Cài đặt nghe truyện'),
                  ),
                ],
              ),
            ),
        ],
      ),
      // Chapter List Bottom Sheet
      bottomSheet: state.showChapterList && state.content != null
          ? _buildChapterList(context, state)
          : null,
    );
  }

  Widget _buildChapterList(BuildContext context, WebReaderState state) {
    final chapters = state.content!.chapters;
    final currentIndex = state.content!.currentChapterIndex;

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Danh sách chương (${chapters.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () =>
                      ref.read(webReaderProvider.notifier).toggleChapterList(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Chapter List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: chapters.length,
              itemBuilder: (context, index) {
                final chapter = chapters[index];
                final isCurrent = index == currentIndex;

                return ListTile(
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: isCurrent
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isCurrent
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  title: Text(
                    chapter.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      color: isCurrent
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                  trailing: isCurrent
                      ? Icon(
                          Icons.play_circle_filled,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () {
                    ref.read(webReaderProvider.notifier).loadChapter(index);
                    if (state.isPlaying) {
                      Future.delayed(const Duration(milliseconds: 300), _speakCurrentContent);
                    }
                  },
                  tileColor: isCurrent
                      ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _addToLibrary(String novelTitle) {
    final library = WebNovelLibrary();
    library.load();
    
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng dán link truyện')),
      );
      return;
    }
    
    if (library.isTracked(url)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Truyện đã có trong thư viện')),
      );
      return;
    }
    
    final item = WebNovelItem(
      id: '${DateTime.now().millisecondsSinceEpoch}',
      title: novelTitle,
      url: url,
      sourceName: _extensionRegistry.detectSource(url)?.name ?? 'Custom',
    );
    
    library.addNovel(item).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã thêm "$novelTitle" vào thư viện'),
          action: SnackBarAction(
            label: 'Xem',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const WebNovelLibraryPage(),
                ),
              );
            },
          ),
        ),
      );
    });
  }
}