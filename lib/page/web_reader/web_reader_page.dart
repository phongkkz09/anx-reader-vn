import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anx_reader/providers/web_reader_provider.dart';
import 'package:anx_reader/service/tts/tts_factory.dart';
import 'package:anx_reader/service/tts/base_tts.dart';
import 'package:anx_reader/service/tts/tts_service.dart';

class WebReaderPage extends ConsumerStatefulWidget {
  const WebReaderPage({Key? key}) : super(key: key);

  @override
  ConsumerState<WebReaderPage> createState() => _WebReaderPageState();
}

class _WebReaderPageState extends ConsumerState<WebReaderPage> {
  final _urlController = TextEditingController();
  late BaseTts _tts;
  bool _ttsInitialized = false;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    _tts = TtsFactory().current;
    await _tts.init(
      () {},
      () async => ref.read(webReaderProvider).content?.content ?? '',
      () async => '',
    );
    _ttsInitialized = true;
  }

  @override
  void dispose() {
    _urlController.dispose();
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
      await _tts.pause();
      notifier.setPlaying(false);
    } else {
      if (state.content?.content.isNotEmpty ?? false) {
        await _tts.speak(content: state.content!.content);
        notifier.setPlaying(true);

        // Listen for completion to auto-load next chapter
        _listenForCompletion();
      }
    }
  }

  void _listenForCompletion() {
    _tts.ttsStateNotifier.addListener(_onTtsStateChange);
  }

  void _onTtsStateChange() {
    if (!_ttsInitialized) return;

    final ttsState = _tts.ttsStateNotifier.value;
    if (ttsState == TtsStateEnum.stopped) {
      final state = ref.read(webReaderProvider);
      if (state.isPlaying) {
        // TTS completed - auto load next chapter if available
        _tts.ttsStateNotifier.removeListener(_onTtsStateChange);
        if (state.content?.hasNextChapter ?? false) {
          ref.read(webReaderProvider.notifier).loadNextChapter();
          // Wait a bit then continue playing
          Future.delayed(const Duration(milliseconds: 500), () {
            if (ref.read(webReaderProvider).isPlaying) {
              _speakCurrentContent();
            }
          });
        } else {
          // No next chapter, stop playing
          ref.read(webReaderProvider.notifier).setPlaying(false);
        }
      }
    }
  }

  Future<void> _speakCurrentContent() async {
    final state = ref.read(webReaderProvider);
    if (state.content?.content.isNotEmpty ?? false) {
      await _tts.speak(content: state.content!.content);
    }
  }

  void _nextChapter() {
    ref.read(webReaderProvider.notifier).loadNextChapter();
    if (ref.read(webReaderProvider).isPlaying) {
      Future.delayed(const Duration(milliseconds: 500), _speakCurrentContent);
    }
  }

  void _prevChapter() {
    ref.read(webReaderProvider.notifier).loadPrevChapter();
    if (ref.read(webReaderProvider).isPlaying) {
      Future.delayed(const Duration(milliseconds: 500), _speakCurrentContent);
    }
  }

  void _showChapterList() {
    ref.read(webReaderProvider.notifier).toggleChapterList();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(webReaderProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nghe truyện từ Web'),
        centerTitle: true,
        actions: [
          if (state.content != null && state.content!.chapters.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.list_alt),
              onPressed: _showChapterList,
              tooltip: 'Danh sách chương (${state.content!.chapters.length})',
            ),
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('TTS Settings - Coming soon'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.settings),
                    label: const Text('Cài đặt giọng đọc'),
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
}