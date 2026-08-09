import 'dart:convert';
import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/utils/iterable_extensions.dart';

/// AI Provider Configuration
class AiProviderConfig {
  final String id;
  final String name;
  final String apiBase;      // e.g. https://api.openai.com/v1
  final String apiKey;
  final String model;        // e.g. gpt-4o-mini
  final String type;         // openai-compatible, anthropic, gemini, custom
  final bool isEnabled;
  final bool isBuiltIn;
  final Map<String, dynamic> extra;  // extra params (temperature, max_tokens...)
  
  const AiProviderConfig({
    required this.id,
    required this.name,
    required this.apiBase,
    this.apiKey = '',
    this.model = '',
    this.type = 'openai-compatible',
    this.isEnabled = true,
    this.isBuiltIn = false,
    this.extra = const {},
  });
  
  /// Whether API key is configured (needed for online providers)
  bool get isConfigured => apiKey.isNotEmpty;
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'apiBase': apiBase,
    'apiKey': apiKey,
    'model': model,
    'type': type,
    'isEnabled': isEnabled,
    'isBuiltIn': isBuiltIn,
    'extra': extra,
  };
  
  factory AiProviderConfig.fromJson(Map<String, dynamic> json) {
    return AiProviderConfig(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      apiBase: json['apiBase'] as String? ?? '',
      apiKey: json['apiKey'] as String? ?? '',
      model: json['model'] as String? ?? '',
      type: json['type'] as String? ?? 'openai-compatible',
      isEnabled: json['isEnabled'] as bool? ?? true,
      isBuiltIn: json['isBuiltIn'] as bool? ?? false,
      extra: Map<String, dynamic>.from(json['extra'] ?? {}),
    );
  }
  
  AiProviderConfig copyWith({
    String? name,
    String? apiBase,
    String? apiKey,
    String? model,
    String? type,
    bool? isEnabled,
    Map<String, dynamic>? extra,
  }) {
    return AiProviderConfig(
      id: id,
      name: name ?? this.name,
      apiBase: apiBase ?? this.apiBase,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      type: type ?? this.type,
      isEnabled: isEnabled ?? this.isEnabled,
      isBuiltIn: isBuiltIn,
      extra: extra ?? this.extra,
    );
  }
}

/// AI Provider Manager
/// Manages AI provider configurations (add/remove/enable/disable)
class AiProviderManager {
  static final AiProviderManager _instance = AiProviderManager._internal();
  factory AiProviderManager() => _instance;
  AiProviderManager._internal();

  static const String _customKey = 'ai_provider_custom';
  static const String _disabledKey = 'ai_provider_disabled';
  static const String _activeKey = 'ai_provider_active';

  List<AiProviderConfig> _customProviders = [];
  Set<String> _disabledIds = {};
  String? _activeId;

  /// Built-in providers (free/on-device friendly)
  final List<AiProviderConfig> builtIn = [
    const AiProviderConfig(
      id: 'system',
      name: 'System (on-device)',
      apiBase: '',
      type: 'system',
      isBuiltIn: true,
      extra: {'description': 'AI chạy trên thiết bị, không cần API key'},
    ),
    const AiProviderConfig(
      id: 'openai',
      name: 'OpenAI',
      apiBase: 'https://api.openai.com/v1',
      model: 'gpt-4o-mini',
      type: 'openai-compatible',
      isBuiltIn: true,
    ),
    const AiProviderConfig(
      id: 'deepseek',
      name: 'DeepSeek',
      apiBase: 'https://api.deepseek.com/v1',
      model: 'deepseek-chat',
      type: 'openai-compatible',
      isBuiltIn: true,
    ),
    const AiProviderConfig(
      id: 'gemini',
      name: 'Google Gemini',
      apiBase: 'https://generativelanguage.googleapis.com/v1beta',
      model: 'gemini-1.5-flash',
      type: 'gemini',
      isBuiltIn: true,
    ),
    const AiProviderConfig(
      id: 'groq',
      name: 'Groq (Free)',
      apiBase: 'https://api.groq.com/openai/v1',
      model: 'llama-3.1-8b-instant',
      type: 'openai-compatible',
      isBuiltIn: true,
    ),
    const AiProviderConfig(
      id: 'ollama',
      name: 'Ollama (Local)',
      apiBase: 'http://localhost:11434/v1',
      model: 'llama3.2',
      type: 'openai-compatible',
      isBuiltIn: true,
    ),
  ];

  /// All providers (built-in + custom)
  List<AiProviderConfig> get all => [...builtIn, ..._customProviders];

  /// Enabled providers only
  List<AiProviderConfig> get enabled => all.where((p) => p.isEnabled).toList();

  /// Configured providers (have API key or system/local)
  List<AiProviderConfig> get configured => enabled.where((p) => 
      p.type == 'system' || p.isConfigured).toList();

  /// Get active provider (or first enabled)
  AiProviderConfig get active {
    if (_activeId != null) {
      final match = all.where((p) => p.id == _activeId).firstOrNull;
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
        _customProviders = list.map((j) => AiProviderConfig.fromJson(j)).toList();
      } catch (_) {
        _customProviders = [];
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
      jsonEncode(_customProviders.map((p) => p.toJson()).toList()),
    );
    Prefs().prefs.setStringList(_disabledKey, _disabledIds.toList());
    if (_activeId != null) {
      Prefs().prefs.setString(_activeKey, _activeId!);
    }
  }

  /// Add custom provider
  void addProvider(AiProviderConfig provider) {
    _customProviders.removeWhere((p) => p.id == provider.id);
    _customProviders.add(provider);
    _save();
  }

  /// Remove custom provider
  void removeProvider(String id) {
    _customProviders.removeWhere((p) => p.id == id);
    _disabledIds.remove(id);
    if (_activeId == id) _activeId = null;
    _save();
  }

  /// Toggle provider enabled/disabled
  void toggleProvider(String id, {bool? enabled}) {
    final provider = getProvider(id);
    if (provider == null) return;
    
    final shouldEnable = enabled ?? _disabledIds.contains(id);
    if (shouldEnable) {
      _disabledIds.remove(id);
    } else {
      _disabledIds.add(id);
      if (_activeId == id) _activeId = null;
    }
    _save();
  }

  /// Set active provider
  void setActive(String id) {
    final provider = getProvider(id);
    if (provider == null || !provider.isEnabled) return;
    _activeId = id;
    _save();
  }

  /// Update provider config
  void updateProvider(AiProviderConfig updated) {
    if (updated.isBuiltIn) {
      // For built-in, store overrides as custom entry with same ID
      _customProviders.removeWhere((p) => p.id == updated.id);
      _customProviders.add(updated.copyWith(isBuiltIn: false));
    } else {
      final index = _customProviders.indexWhere((p) => p.id == updated.id);
      if (index >= 0) {
        _customProviders[index] = updated;
      }
    }
    _save();
  }

  /// Get provider by ID
  AiProviderConfig? getProvider(String id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Search providers
  List<AiProviderConfig> search(String query) {
    final q = query.toLowerCase();
    return all.where((p) =>
      p.name.toLowerCase().contains(q) ||
      p.model.toLowerCase().contains(q) ||
      p.apiBase.toLowerCase().contains(q)
    ).toList();
  }

  /// Check if provider is configured (has key or system)
  bool isProviderConfigured(String id) {
    final p = getProvider(id);
    return p != null && (p.type == 'system' || p.isConfigured);
  }

  /// Get API key for a provider (for actual API calls)
  String getApiKey(String id) {
    final p = getProvider(id);
    return p?.apiKey ?? '';
  }

  /// Import providers from JSON
  int importFromJson(String jsonString) {
    try {
      final List<dynamic> list = jsonDecode(jsonString);
      int imported = 0;
      for (final item in list) {
        final p = AiProviderConfig.fromJson(item as Map<String, dynamic>);
        if (p.id.isNotEmpty && p.apiBase.isNotEmpty) {
          addProvider(p);
          imported++;
        }
      }
      return imported;
    } catch (_) {
      return 0;
    }
  }

  /// Export custom providers to JSON
  String exportToJson() {
    return jsonEncode(_customProviders.map((p) => p.toJson()).toList());
  }

  /// Get active provider ID
  String? get activeId => _activeId;
}
