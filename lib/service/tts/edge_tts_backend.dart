import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:anx_reader/service/tts/models/tts_voice.dart';

/// Edge TTS Provider
/// Free TTS service using Microsoft Edge's online TTS API
/// No API key required, supports Vietnamese voices
/// 
/// Note: This is a standalone TTS provider (not tied to TtsService enum)
/// Integrate via TtsBackendManager in web_reader module
class EdgeTtsProvider {
  static const String _edgeTtsUrl = 'https://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1';

  // Popular Vietnamese and multi-language voices
  static const Map<String, String> _vietnameseVoices = {
    'vi-VN-NamMinNeural': 'Nam Minh (Nam)',
    'vi-VN-HoaiMyNeural': 'Hoài My (Nữ)',
  };

  static const Map<String, String> _popularVoices = {
    'en-US-AriaNeural': 'Aria (US English, Female)',
    'en-US-GuyNeural': 'Guy (US English, Male)',
    'en-GB-SoniaNeural': 'Sonia (UK English, Female)',
    'zh-CN-XiaoxiaoNeural': 'Xiaoxiao (Chinese, Female)',
    'ja-JP-NanamiNeural': 'Nanami (Japanese, Female)',
    'ko-KR-SunHiNeural': 'SunHi (Korean, Female)',
  };

  final Dio _dio = Dio();

  String get serviceId => 'edge';
  String getLabel(BuildContext context) => 'Edge TTS (Free)';

  Future<List<TtsVoice>> getVoices() async {
    final voices = <TtsVoice>[];

    // Add Vietnamese voices first
    for (final entry in _vietnameseVoices.entries) {
      voices.add(TtsVoice(
        shortName: entry.key,
        name: entry.value,
        locale: 'vi-VN',
        gender: 'Male',
      ));
    }

    // Add popular voices
    for (final entry in _popularVoices.entries) {
      voices.add(TtsVoice(
        shortName: entry.key,
        name: entry.value,
        locale: entry.key.split('-').take(2).join('-'),
      ));
    }

    return voices;
  }

  Future<Uint8List> speak(String text, String? voice, double rate, double pitch) async {
    // Resolve voice
    final voiceId = voice ?? 'vi-VN-NamMinNeural';

    // Convert rate (0.5-2.0) to Edge format (-100% to +100%)
    final edgeRate = ((rate - 1.0) * 100).round();

    // Build SSML
    final ssml = '''
<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="vi-VN">
  <voice name="$voiceId">
    <prosody rate="$edgeRate%" pitch="${pitch > 1 ? '+' : ''}${((pitch - 1.0) * 50).round()}%">
      $text
    </prosody>
  </voice>
</speak>
''';

    try {
      // Request audio from Edge TTS
      final response = await _dio.post<Uint8List>(
        '$_edgeTtsUrl?trustedclienttoken=&Retry-ID=',
        data: ssml,
        options: Options(
          headers: {
            'Content-Type': 'application/ssml+xml',
            'X-Microsoft-OutputFormat': 'audio-24khz-48kbitrate-mono-mp3',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          },
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      return response.data ?? Uint8List(0);
    } catch (e) {
      debugPrint('EdgeTtsProvider.speak error: $e');
      rethrow;
    }
  }

  TtsVoice convertVoiceModel(dynamic voiceData) {
    if (voiceData is Map<String, dynamic>) {
      return TtsVoice.fromMap(voiceData);
    }
    return TtsVoice(
      shortName: 'unknown',
      name: 'Unknown',
      locale: 'en-US',
    );
  }
}
