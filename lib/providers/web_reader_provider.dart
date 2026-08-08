import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anx_reader/service/web_reader/web_content_extractor.dart';
import 'package:anx_reader/config/shared_preference_provider.dart';

/// State for web reader
class WebReaderState {
  final String? url;
  final WebContent? content;
  final bool isLoading;
  final String? error;
  final bool isPlaying;
  final bool showChapterList;

  WebReaderState({
    this.url,
    this.content,
    this.isLoading = false,
    this.error,
    this.isPlaying = false,
    this.showChapterList = false,
  });

  WebReaderState copyWith({
    String? url,
    WebContent? content,
    bool? isLoading,
    String? error,
    bool? isPlaying,
    bool? showChapterList,
  }) {
    return WebReaderState(
      url: url ?? this.url,
      content: content ?? this.content,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isPlaying: isPlaying ?? this.isPlaying,
      showChapterList: showChapterList ?? this.showChapterList,
    );
  }

  /// Chapter info string
  String get chapterInfo {
    if (content == null || content!.chapters.isEmpty) return '';
    final current = content!.currentChapterIndex + 1;
    final total = content!.chapters.length;
    return '$current / $total';
  }
}

/// Notifier for web reader state
class WebReaderNotifier extends StateNotifier<WebReaderState> {
  final WebContentExtractor _extractor = WebContentExtractor();
  final VoidCallback? _onChapterChanged;

  WebReaderNotifier({VoidCallback? onChapterChanged})
      : _onChapterChanged = onChapterChanged,
        super(WebReaderState()) {
    _restoreProgress();
  }

  /// Restore last reading position
  void _restoreProgress() {
    final savedUrl = Prefs().prefs.getString('web_reader_last_url') ?? '';
    if (savedUrl.isNotEmpty) {
      loadContent(savedUrl, saveProgress: false);
    }
  }

  /// Save current reading position
  void _saveProgress(String url) {
    Prefs().prefs.setString('web_reader_last_url', url);
  }

  /// Fetch and extract content from URL
  Future<void> loadContent(String url, {bool saveProgress = true}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final content = await _extractor.extractContent(url);
      state = state.copyWith(
        url: url,
        content: content,
        isLoading: false,
      );

      if (saveProgress) {
        _saveProgress(url);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Load next chapter
  Future<void> loadNextChapter() async {
    if (state.content?.nextChapterUrl == null) return;
    await loadContent(state.content!.nextChapterUrl!);
    _onChapterChanged?.call();
  }

  /// Load previous chapter
  Future<void> loadPrevChapter() async {
    if (state.content?.prevChapterUrl == null) return;
    await loadContent(state.content!.prevChapterUrl!);
    _onChapterChanged?.call();
  }

  /// Load specific chapter by index
  Future<void> loadChapter(int index) async {
    if (state.content == null) return;
    if (index < 0 || index >= state.content!.chapters.length) return;

    final chapter = state.content!.chapters[index];
    await loadContent(chapter.url);
    state = state.copyWith(showChapterList: false);
    _onChapterChanged?.call();
  }

  /// Toggle chapter list visibility
  void toggleChapterList() {
    state = state.copyWith(showChapterList: !state.showChapterList);
  }

  /// Update playing state
  void setPlaying(bool isPlaying) {
    state = state.copyWith(isPlaying: isPlaying);
  }

  /// Clear content
  void clear() {
    state = WebReaderState();
  }
}

/// Riverpod provider for web reader
final webReaderProvider =
    StateNotifierProvider<WebReaderNotifier, WebReaderState>(
  (ref) => WebReaderNotifier(
    onChapterChanged: () {
      // Notify settings for sleep timer
      WebReaderSettings().chapterChanged();
    },
  ),
);
