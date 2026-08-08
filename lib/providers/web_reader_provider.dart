import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'web_content_extractor.dart';

/// State for web reader
class WebReaderState {
  final String? url;
  final WebContent? content;
  final bool isLoading;
  final String? error;
  final bool isPlaying;

  WebReaderState({
    this.url,
    this.content,
    this.isLoading = false,
    this.error,
    this.isPlaying = false,
  });

  WebReaderState copyWith({
    String? url,
    WebContent? content,
    bool? isLoading,
    String? error,
    bool? isPlaying,
  }) {
    return WebReaderState(
      url: url ?? this.url,
      content: content ?? this.content,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      isPlaying: isPlaying ?? this.isPlaying,
    );
  }
}

/// Notifier for web reader state
class WebReaderNotifier extends StateNotifier<WebReaderState> {
  final WebContentExtractor _extractor = WebContentExtractor();

  WebReaderNotifier() : super(WebReaderState());

  /// Fetch and extract content from URL
  Future<void> loadContent(String url) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final content = await _extractor.extractContent(url);
      state = state.copyWith(
        url: url,
        content: content,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Load next chapter
  Future<void> loadNextChapter() async {
    if (state.content?.nextChapterUrl == null) {
      state = state.copyWith(
        error: 'No next chapter available',
      );
      return;
    }

    await loadContent(state.content!.nextChapterUrl!);
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
  (ref) => WebReaderNotifier(),
);
