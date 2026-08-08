import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anx_reader/providers/web_reader_provider.dart';
import 'package:anx_reader/service/tts/tts_factory.dart';

class WebReaderPage extends ConsumerStatefulWidget {
  const WebReaderPage({Key? key}) : super(key: key);

  @override
  ConsumerState<WebReaderPage> createState() => _WebReaderPageState();
}

class _WebReaderPageState extends ConsumerState<WebReaderPage> {
  final _urlController = TextEditingController();
  late Future<void> _ttsInitFuture;

  @override
  void initState() {
    super.initState();
    // Initialize TTS
    _ttsInitFuture = _initTts();
  }

  Future<void> _initTts() async {
    final tts = TtsFactory().current;
    // Initialize with dummy functions for web reader
    await tts.init(
      () {}, // getCurrentText
      () async => ref.read(webReaderProvider).content?.content ?? '',
      () async => '', // getPrevText
    );
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

  void _togglePlayPause() async {
    final notifier = ref.read(webReaderProvider.notifier);
    final state = ref.read(webReaderProvider);
    final tts = TtsFactory().current;

    if (state.isPlaying) {
      await tts.pause();
      notifier.setPlaying(false);
    } else {
      if (state.content?.content.isNotEmpty ?? false) {
        await tts.speak(content: state.content!.content);
        notifier.setPlaying(true);
      }
    }
  }

  void _nextChapter() {
    ref.read(webReaderProvider.notifier).loadNextChapter();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(webReaderProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nghe truyện từ Web'),
        centerTitle: true,
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
                  // Content Title
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.grey.shade100,
                    child: Text(
                      state.content!.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
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
                  // Playback Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton.filled(
                        onPressed: state.isLoading ? null : _togglePlayPause,
                        icon: Icon(
                          state.isPlaying ? Icons.pause : Icons.play_arrow,
                        ),
                        tooltip: state.isPlaying ? 'Tạm dừng' : 'Phát',
                      ),
                      const SizedBox(width: 16),
                      if (state.content!.nextChapterUrl != null)
                        IconButton.filled(
                          onPressed: state.isLoading ? null : _nextChapter,
                          icon: const Icon(Icons.skip_next),
                          tooltip: 'Chương tiếp theo',
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // TTS Settings Button
                  ElevatedButton.icon(
                    onPressed: () {
                      // Navigate to TTS settings
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
    );
  }
}
