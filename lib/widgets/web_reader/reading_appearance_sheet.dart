import 'package:flutter/material.dart';
import 'package:anx_reader/service/web_reader/reading_settings.dart';

/// Reading Appearance Sheet
/// Lets user choose theme, font, font size, line height
class ReadingAppearanceSheet extends StatefulWidget {
  const ReadingAppearanceSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ReadingAppearanceSheet(),
    );
  }

  @override
  State<ReadingAppearanceSheet> createState() => _ReadingAppearanceSheetState();
}

class _ReadingAppearanceSheetState extends State<ReadingAppearanceSheet> {
  final ReadingSettings _settings = ReadingSettings();
  late ReadingTheme _currentTheme;
  late ReadingFont _currentFont;
  late double _fontSize;
  late double _lineHeight;

  @override
  void initState() {
    super.initState();
    _currentTheme = _settings.theme;
    _currentFont = _settings.font;
    _fontSize = _settings.fontSize;
    _lineHeight = _settings.lineHeight;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Giao diện đọc',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Theme selector
              const Text(
                'Chủ đề:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: ReadingSettings.themes.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final theme = ReadingSettings.themes[index];
                    final isSelected = theme.id == _currentTheme.id;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _currentTheme = theme;
                          _settings.setTheme(theme.id);
                        });
                      },
                      child: Column(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: theme.background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? theme.accent
                                    : Colors.grey.shade300,
                                width: isSelected ? 3 : 1,
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.format_size,
                                color: theme.text,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            theme.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Font selector
              const Text(
                'Font chữ:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ReadingSettings.fonts.map((font) {
                  final isSelected = font.id == _currentFont.id;
                  return ChoiceChip(
                    label: Text(font.name),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() {
                        _currentFont = font;
                        _settings.setFont(font.id);
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Font size slider
              Row(
                children: [
                  const Text('Cỡ chữ:', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 12),
                  Icon(Icons.text_fields, size: 18, color: Colors.grey.shade600),
                  Expanded(
                    child: Slider(
                      value: _fontSize,
                      min: 12,
                      max: 28,
                      divisions: 16,
                      label: '${_fontSize.toStringAsFixed(0)}',
                      onChanged: (v) {
                        setState(() => _fontSize = v);
                        _settings.setFontSize(v);
                      },
                    ),
                  ),
                  Text('${_fontSize.toStringAsFixed(0)}'),
                ],
              ),

              // Line height slider
              Row(
                children: [
                  const Text('Giãn dòng:', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 12),
                  Icon(Icons.format_line_spacing, size: 18, color: Colors.grey.shade600),
                  Expanded(
                    child: Slider(
                      value: _lineHeight,
                      min: 1.2,
                      max: 2.5,
                      divisions: 13,
                      label: '${_lineHeight.toStringAsFixed(1)}',
                      onChanged: (v) {
                        setState(() => _lineHeight = v);
                        _settings.setLineHeight(v);
                      },
                    ),
                  ),
                  Text('${_lineHeight.toStringAsFixed(1)}'),
                ],
              ),

              // Preview
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _currentTheme.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Xem trước:',
                      style: TextStyle(
                        fontSize: 12,
                        color: _currentTheme.text.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Đêm khuya, ánh trăng soi qua khung cửa sổ. Nhân vật chính ngồi bên bàn đọc một cuốn truyện cũ...',
                      style: TextStyle(
                        fontSize: _fontSize,
                        height: _lineHeight,
                        color: _currentTheme.text,
                        fontFamily: _currentFont.fontFamily.isEmpty
                            ? null
                            : _currentFont.fontFamily,
                      ),
                    ),
                  ],
                ),
              ),

              // Reset button
              const SizedBox(height: 16),
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    _settings.reset();
                    setState(() {
                      _currentTheme = _settings.theme;
                      _currentFont = _settings.font;
                      _fontSize = _settings.fontSize;
                      _lineHeight = _settings.lineHeight;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã khôi phục mặc định')),
                    );
                  },
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Khôi phục mặc định'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
