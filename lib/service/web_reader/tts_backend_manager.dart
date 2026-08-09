import 'dart:convert';
import 'package:anx_reader/config/shared_preference_provider.dart';

/// TTS Backend Configuration
class TtsBackendConfig {
  final String id;
  final String name;
  final String type;       // system, openai, azure, aliyun, custom
  final String apiBase;
  final String apiKey;
  final String voice;      // voice name/ID
  final int sampleRate;
  final bool isEnabled;
  final bool isBuiltIn;
  final Map<String, dynamic> extra;  // extra params (language, speed, pitch...)
  
  const TtsBackendConfig({
    required this.id,
    required this.name,
    required this.type,
    this.apiBase = '',
    this.apiKey = '',
    this.voice = '',
    this.sampleRate = 22050,
    this.isEnabled = true,
    this.isBuiltIn = false,
    this.extra = const {},
  });
  
  bool get isConfigured => type == 'system' || apiKey.isNotEmpty;
  bool get isOnline => type != 'system';
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'apiBase': apiBase,
    'apiKey': apiKey,
    'voice': voice,
    'sampleRate': sampleRate,
    'isEnabled': isEnabled,
    'isBuiltIn': isBuiltIn,
    'extra': extra,
  };
  
  factory TtsBackendConfig.fromJson(Map<String, dynamic> json) {
    return TtsBackendConfig(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? 'system',
      apiBase: json['apiBase'] as String? ?? '',
      apiKey: json['apiKey'] as String? ?? '',
      voice: json['voice'] as String? ?? '',
      sampleRate: json['sampleRate'] as int? ?? 22050,
      isEnabled: json['isEnabled'] as bool? ?? true,
      isBuiltIn: json['isBuiltIn'] as bool? ?? false,
      extra: Map<String, dynamic>.from(json['extra'] ?? {}),
    );
  }
  
  TtsBackendConfig copyWith({
    String? name,
    String? apiBase,
    String? apiKey,
    String? voice,
    int? sampleRate,
    bool? isEnabled,
    Map<String, dynamic>? extra,
  }) {
    return TtsBackendConfig(
      id: id,
      name: name ?? this.name,
      type: type,
      apiBase: apiBase ?? this.apiBase,
      apiKey: apiKey ?? this.apiKey,
      voice: voice ?? this.voice,
      sampleRate: sampleRate ?? this.sampleRate,
      isEnabled: isEnabled ?? this.isEnabled,
      isBuiltIn: isBuiltIn,
      extra: extra ?? this.extra,
    );
  }
}

/// TTS Backend Manager
/// Manages TTS backend configurations (system, OpenAI, Azure, Aliyun, custom)
class TtsBackendManager {
  static final TtsBackendManager _instance = TtsBackendManager._internal();
  factory TtsBackendManager() => _instance;
  TtsBackendManager._internal();

  static const String _customKey = 'tts_backend_custom';
  static const String _disabledKey = 'tts_backend_disabled';
  static const String _activeKey = 'tts_backend_active';

  List<TtsBackendConfig> _customBackends = [];
  Set<String> _disabledIds = {};
  String? _activeId;

  /// Built-in TTS backends
  final List<TtsBackendConfig> builtIn = [
    const TtsBackendConfig(
      id: 'system',
      name: 'System TTS (on-device)',
      type: 'system',
      isBuiltIn: true,
      extra: {'description': 'TTS mặc định của thiết bị'},
    ),
    const TtsBackendConfig(
      id: 'openai_tts',
      name: 'OpenAI TTS',
      type: 'openai',
      apiBase: 'https://api.openai.com/v1',
      voice: 'nova',
      sampleRate: 22050,
      isBuiltIn: true,
    ),
    const TtsBackendConfig(
      id: 'azure_tts',
      name: 'Azure TTS',
      type: 'azure',
      apiBase: 'https://eastus.tts.speech.microsoft.com',
      voice: 'vi-VN-NamMinNeural',
      sampleRate: 24000,
      isBuiltIn: true,
    ),
    const TtsBackendConfig(
      id: 'aliyun_tts',
      name: 'Aliyun TTS (Chinese)',
      type: 'aliyun',
      apiBase: 'https://nls-gateway-cn-shanghai.aliyuncs.com',
      voice: 'xiaoyun',
      sampleRate: 16000,
      isBuiltIn: true,
    ),
    const TtsBackendConfig(
      id: 'edge_tts',
      name: 'Edge TTS (Free)',
      type: 'edge',
      apiBase: '',
      voice: 'vi-VN-NamMinNeural',
      sampleRate: 24000,
      isBuiltIn: true,
      extra: {'description': 'Free TTS via Edge browser API'},
    ),
    const TtsBackendConfig(
      id: 'google_tts',
      name: 'Google Cloud TTS',
      type: 'google',
      apiBase: 'https://texttospeech.googleapis.com/v1',
      voice: 'vi-VN-Wavenet-A',
      sampleRate: 24000,
      isBuiltIn: true,
    ),
  ];

  /// All backends (built-in + custom)
  List<TtsBackendConfig> get all => [...builtIn, ..._customBackends];

  /// Enabled backends only
  List<TtsBackendConfig> get enabled => all.where((b) => b.isEnabled).toList();

  /// Configured backends (have API key or system)
  List<TtsBackendConfig> get configured => enabled.where((b) => b.isConfigured).toList();

  /// Get active backend
  TtsBackendConfig get active {
    if (_activeId != null) {
      final match = all.where((b) => b.id == _activeId).firstOrNull;
      if (match != null && match.isEnabled) return match;
    }
    final first = enabled.firstOrNull;
    return first ?? builtIn.first;
  }

  /// Load from SharedPreferences
  void load() {
    final customJson = Prefs().prefs.getString(_customKey);
    if (customJson != null && customJson.isNotEmpty) {
      try {
        final list = List<Map<String, dynamic>>.from(
          (jsonDecode(customJson) as List).cast<Map<String, dynamic>>(),
        );
        _customBackends = list.map((j) => TtsBackendConfig.fromJson(j)).toList();
      } catch (_) {
        _customBackends = [];
      }
    }
    
    final disabledList = Prefs().prefs.getStringList(_disabledKey) ?? [];
    _disabledIds = disabledList.toSet();
    
    _activeId = Prefs().prefs.getString(_activeKey);
  }

  /// Save to SharedPreferences
  void _save() {
    Prefs().prefs.setString(
      _customKey,
      jsonEncode(_customBackends.map((b) => b.toJson()).toList()),
    );
    Prefs().prefs.setStringList(_disabledKey, _disabledIds.toList());
    if (_activeId != null) {
      Prefs().prefs.setString(_activeKey, _activeId!);
    }
  }

  /// Add custom backend
  void addBackend(TtsBackendConfig backend) {
    _customBackends.removeWhere((b) => b.id == backend.id);
    _customBackends.add(backend);
    _save();
  }

  /// Remove custom backend
  void removeBackend(String id) {
    _customBackends.removeWhere((b) => b.id == id);
    _disabledIds.remove(id);
    if (_activeId == id) _activeId = null;
    _save();
  }

  /// Toggle backend enabled/disabled
  void toggleBackend(String id, {bool? enabled}) {
    final backend = getBackend(id);
    if (backend == null) return;
    
    final shouldEnable = enabled ?? _disabledIds.contains(id);
    if (shouldEnable) {
      _disabledIds.remove(id);
    } else {
      _disabledIds.add(id);
      if (_activeId == id) _activeId = null;
    }
    _save();
  }

  /// Set active backend
  void setActive(String id) {
    final backend = getBackend(id);
    if (backend == null || !backend.isEnabled) return;
    _activeId = id;
    _save();
  }

  /// Update backend config
  void updateBackend(TtsBackendConfig updated) {
    if (updated.isBuiltIn) {
      _customBackends.removeWhere((b) => b.id == updated.id);
      _customBackends.add(updated.copyWith(isBuiltIn: false));
    } else {
      final index = _customBackends.indexWhere((b) => b.id == updated.id);
      if (index >= 0) {
        _customBackends[index] = updated;
      }
    }
    _save();
  }

  /// Get backend by ID
  TtsBackendConfig? getBackend(String id) {
    for (final b in all) {
      if (b.id == id) return b;
    }
    return null;
  }

  /// Search backends
  List<TtsBackendConfig> search(String query) {
    final q = query.toLowerCase();
    return all.where((b) =>
      b.name.toLowerCase().contains(q) ||
      b.type.toLowerCase().contains(q) ||
      b.voice.toLowerCase().contains(q)
    ).toList();
  }

  /// Check if backend is configured
  bool isBackendConfigured(String id) {
    final b = getBackend(id);
    return b != null && b.isConfigured;
  }

  /// Get API key for backend
  String getApiKey(String id) {
    final b = getBackend(id);
    return b?.apiKey ?? '';
  }

  /// Import backends from JSON
  int importFromJson(String jsonString) {
    try {
      final List<dynamic> list = jsonDecode(jsonString);
      int imported = 0;
      for (final item in list) {
        final b = TtsBackendConfig.fromJson(item as Map<String, dynamic>);
        if (b.id.isNotEmpty) {
          addBackend(b);
          imported++;
        }
      }
      return imported;
    } catch (_) {
      return 0;
    }
  }

  /// Export custom backends to JSON
  String exportToJson() {
    return jsonEncode(_customBackends.map((b) => b.toJson()).toList());
  }

  /// Get active backend ID
  String? get activeId => _activeId;
}

/// Extension for firstOrNull
extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
