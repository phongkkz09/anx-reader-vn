import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:flutter/material.dart';

/// Reading theme preset
class ReadingTheme {
  final String id;
  final String name;
  final Color background;
  final Color text;
  final Color accent;

  const ReadingTheme({
    required this.id,
    required this.name,
    required this.background,
    required this.text,
    required this.accent,
  });
}

/// Reading font preset
class ReadingFont {
  final String id;
  final String name;
  final String fontFamily; // null = system default
  final double defaultSize;

  const ReadingFont({
    required this.id,
    required this.name,
    this.fontFamily = '',
    this.defaultSize = 16,
  });
}

/// Reading Settings Service
/// Manages theme, font, and text size preferences
class ReadingSettings {
  static final ReadingSettings _instance = ReadingSettings._internal();
  factory ReadingSettings() => _instance;
  ReadingSettings._internal();

  static const String _themeKey = 'reading_theme_id';
  static const String _fontKey = 'reading_font_id';
  static const String _fontSizeKey = 'reading_font_size';
  static const String _lineHeightKey = 'reading_line_height';

  // Available themes
  static const List<ReadingTheme> themes = [
    ReadingTheme(
      id: 'light',
      name: 'Sáng',
      background: Color(0xFFFFFFFF),
      text: Color(0xFF212121),
      accent: Color(0xFF2196F3),
    ),
    ReadingTheme(
      id: 'dark',
      name: 'Tối',
      background: Color(0xFF121212),
      text: Color(0xFFE0E0E0),
      accent: Color(0xFF90CAF9),
    ),
    ReadingTheme(
      id: 'sepia',
      name: 'Sepia',
      background: Color(0xFFF4ECD8),
      text: Color(0xFF5B4636),
      accent: Color(0xFF8D6E63),
    ),
    ReadingTheme(
      id: 'green',
      name: 'Xanh (bảo vệ mắt)',
      background: Color(0xFFC7EDCC),
      text: Color(0xFF2F4F2F),
      accent: Color(0xFF4CAF50),
    ),
  ];

  // Available fonts
  static const List<ReadingFont> fonts = [
    ReadingFont(id: 'system', name: 'Mặc định', defaultSize: 16),
    ReadingFont(id: 'serif', name: 'Serif (sách)', fontFamily: 'serif', defaultSize: 16),
    ReadingFont(id: 'sans', name: 'Sans (gọn)', fontFamily: 'sans-serif', defaultSize: 15),
    ReadingFont(id: 'mono', name: 'Mono (máy đánh chữ)', fontFamily: 'monospace', defaultSize: 14),
  ];

  /// Current theme
  ReadingTheme get theme {
    final id = Prefs().prefs.getString(_themeKey) ?? 'light';
    return themes.firstWhere(
      (t) => t.id == id,
      orElse: () => themes.first,
    );
  }

  /// Set theme
  void setTheme(String id) {
    Prefs().prefs.setString(_themeKey, id);
  }

  /// Current font
  ReadingFont get font {
    final id = Prefs().prefs.getString(_fontKey) ?? 'system';
    return fonts.firstWhere(
      (f) => f.id == id,
      orElse: () => fonts.first,
    );
  }

  /// Set font
  void setFont(String id) {
    Prefs().prefs.setString(_fontKey, id);
  }

  /// Font size (default 16)
  double get fontSize {
    return Prefs().prefs.getDouble(_fontSizeKey) ?? 16.0;
  }

  /// Set font size
  void setFontSize(double size) {
    Prefs().prefs.setDouble(_fontSizeKey, size.clamp(12.0, 28.0));
  }

  /// Line height (default 1.6)
  double get lineHeight {
    return Prefs().prefs.getDouble(_lineHeightKey) ?? 1.6;
  }

  /// Set line height
  void setLineHeight(double height) {
    Prefs().prefs.setDouble(_lineHeightKey, height.clamp(1.2, 2.5));
  }

  /// Text style for reading content
  TextStyle readingStyle() {
    return TextStyle(
      fontSize: fontSize,
      height: lineHeight,
      color: theme.text,
      fontFamily: font.fontFamily.isEmpty ? null : font.fontFamily,
    );
  }

  /// Background color for reading area
  Color get backgroundColor => theme.background;

  /// Reset to defaults
  void reset() {
    Prefs().prefs.remove(_themeKey);
    Prefs().prefs.remove(_fontKey);
    Prefs().prefs.remove(_fontSizeKey);
    Prefs().prefs.remove(_lineHeightKey);
  }
}
