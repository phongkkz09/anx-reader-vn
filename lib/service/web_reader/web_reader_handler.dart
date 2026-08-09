import 'package:flutter/foundation.dart';
import 'package:anx_reader/service/tts/base_tts.dart';
import 'package:anx_reader/service/tts/tts_factory.dart';
import 'package:anx_reader/service/web_reader/web_reader_settings.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';

/// Audio handler for Web Reader background playback
/// Manages notification controls, audio session, and TTS state
class WebReaderHandler extends BaseAudioHandler with SeekHandler {
  static final WebReaderHandler _instance = WebReaderHandler._internal();

  factory WebReaderHandler() => _instance;

  WebReaderHandler._internal() {
    _initAudioSession();
  }

  final TtsFactory _ttsFactory = TtsFactory();
  BaseTts get tts => _ttsFactory.current;

  // Callbacks for content retrieval
  Function? _getCurrentText;
  Function? _getNextText;
  Function? _getPrevText;
  
  // Callbacks for navigation
  VoidCallback? _onNextChapter;
  VoidCallback? _onPrevChapter;
  VoidCallback? _onStop;

  // Current content metadata
  String _currentTitle = 'Web Reader';
  String _currentUrl = '';
  
  // Pronunciation settings reference
  final WebReaderSettings _settings = WebReaderSettings();

  /// Initialize the handler with callbacks
  Future<void> init({
    required Function getCurrentText,
    required Function getNextText,
    required Function getPrevText,
    VoidCallback? onNextChapter,
    VoidCallback? onPrevChapter,
    VoidCallback? onStop,
  }) async {
    _getCurrentText = getCurrentText;
    _getNextText = getNextText;
    _getPrevText = getPrevText;
    _onNextChapter = onNextChapter;
    _onPrevChapter = onPrevChapter;
    _onStop = onStop;

    await tts.init(getCurrentText, getNextText, getPrevText);
  }

  /// Set current content metadata for notification
  void setMetadata({
    required String title,
    String? url,
  }) {
    _currentTitle = title;
    _currentUrl = url ?? '';
  }

  Future<void> _initAudioSession() async {
    final session = await AudioSession.instance;

    await session.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      avAudioSessionMode: AVAudioSessionMode.spokenAudio,
    ));

    // Handle audio interruptions (calls, other apps)
    session.interruptionEventStream.listen((event) {
      if (event.begin) {
        if (tts.isPlaying) {
          pause();
        }
      } else {
        switch (event.type) {
          case AudioInterruptionType.pause:
          case AudioInterruptionType.duck:
            if (!tts.isPlaying) {
              play();
            }
            break;
          case AudioInterruptionType.unknown:
            break;
        }
      }
    });

    // Handle headphone unplug
    session.becomingNoisyEventStream.listen((_) {
      if (tts.isPlaying) pause();
    });
  }

  @override
  Future<void> play() async {
    final session = await AudioSession.instance;
    if (await session.setActive(true)) {
      playbackState.add(playbackState.value.copyWith(
        controls: [MediaControl.pause, MediaControl.stop],
        processingState: AudioProcessingState.ready,
        playing: true,
      ));
    }

    final item = MediaItem(
      id: _currentUrl,
      title: _currentTitle,
      album: 'Web Reader',
      artist: 'Đang nghe truyện',
      duration: const Duration(milliseconds: -1),
    );

    queue.add([item]);
    mediaItem.add(item);

    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        MediaControl.pause,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      processingState: AudioProcessingState.ready,
      playing: true,
      queueIndex: 0,
      updatePosition: Duration.zero,
      bufferedPosition: Duration.zero,
    ));

    if (tts.ttsStateNotifier.value == TtsStateEnum.paused) {
      tts.updateTtsState(TtsStateEnum.playing);
      await tts.resume();
    } else {
      tts.updateTtsState(TtsStateEnum.playing);
      await _speakWithPronunciation();
    }
  }

  @override
  Future<void> pause() async {
    playbackState.add(playbackState.value.copyWith(
      controls: [MediaControl.play, MediaControl.stop],
      queueIndex: queue.value.isNotEmpty ? 0 : null,
      processingState: AudioProcessingState.ready,
      playing: false,
    ));

    await tts.pause();
    tts.updateTtsState(TtsStateEnum.paused);
  }

  @override
  Future<void> stop() async {
    playbackState.add(playbackState.value.copyWith(
      controls: [],
      queueIndex: null,
      processingState: AudioProcessingState.idle,
      playing: false,
    ));

    tts.updateTtsState(TtsStateEnum.stopped);
    await tts.stop();
    
    _onStop?.call();
  }

  @override
  Future<void> skipToNext() async {
    // Load next chapter and continue playing
    if (_onNextChapter != null) {
      _onNextChapter!();
    } else {
      await tts.next();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    // Load previous chapter
    if (_onPrevChapter != null) {
      _onPrevChapter!();
    } else {
      await tts.prev();
    }
  }

  /// Get TTS state notifier
  ValueNotifier<TtsStateEnum> get ttsStateNotifier => tts.ttsStateNotifier;

  /// Check if currently playing
  bool get isPlaying => tts.isPlaying;

  /// Set volume (0.0 - 1.0)
  set volume(double volume) => tts.volume = volume;
  double get volume => tts.volume;

  /// Set pitch
  set pitch(double pitch) => tts.pitch = pitch;
  double get pitch => tts.pitch;

  /// Set rate (speed)
  set rate(double rate) => tts.rate = rate;
  double get rate => tts.rate;

  /// Speak text with pronunciation applied
  /// This ensures pronunciation dictionary is respected regardless of
  /// whether TTS is triggered from UI, notification, or background playback
  Future<void> _speakWithPronunciation() async {
    // Get current text from callback
    if (_getCurrentText == null) return;
    
    final text = await _getCurrentText!() as String;
    if (text.isEmpty) return;
    
    // Apply pronunciation dictionary
    final processedText = _settings.applyPronunciations(text);
    
    // Speak the processed text
    await tts.speak(content: processedText);
  }

  /// Dispose resources
  Future<void> dispose() async {
    await tts.dispose();
  }
}

typedef VoidCallback = void Function();
