import 'package:flutter/material.dart';
import 'package:anx_reader/service/web_reader/content_cache_service.dart';

/// Cache Manager Sheet
/// Shows cached items, allows clear/search, displays stats
class CacheManagerSheet extends StatefulWidget {
  const CacheManagerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CacheManagerSheet(),
    );
  }

  @override
  State<CacheManagerSheet> createState() => _CacheManagerSheetState();
}

class _CacheManagerSheetState extends State<CacheManagerSheet> {
  final ContentCacheService _cache = ContentCacheService();
  String _searchQuery = '';
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _cache.init();
    await _cache.cleanup(); // Auto-clean old entries
    setState(() => _isInitialized = true);
  }

  List<CacheItem> get _displayItems {
    if (_searchQuery.isNotEmpty) {
      return _cache.search(_searchQuery);
    }
    return _cache.all;
  }

  @override
  Widget build(BuildContext context) {
    final stats = _cache.getStats();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Title + Stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.storage, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Quản lý bộ nhớ đệm',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (stats.itemCount > 0)
                  Text(
                    '${stats.itemCount} mục · ${stats.totalSizeKB} KB',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Tìm trong bộ nhớ đệm...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),

          // Cache items list
          Expanded(
            child: !_isInitialized
                ? const Center(child: CircularProgressIndicator())
                : _displayItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.cloud_off, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'Không tìm thấy kết quả'
                                  : 'Chưa có mục nào trong bộ nhớ đệm',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _displayItems.length,
                        itemBuilder: (context, index) {
                          final item = _displayItems[index];
                          final sizeKB = (item.sizeBytes / 1024).toStringAsFixed(1);
                          final age = _formatAge(item.cachedAt);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 6),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue.shade50,
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              title: Text(
                                item.title.isNotEmpty ? item.title : item.url,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13),
                              ),
                              subtitle: Text(
                                '$sizeKB KB · Đã lưu $age · Truy cập ${item.accessCount} lần',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              ),
                              trailing: PopupMenuButton<String>(
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_outline, size: 18),
                                        SizedBox(width: 8),
                                        Text('Xóa'),
                                      ],
                                    ),
                                  ),
                                ],
                                onSelected: (action) async {
                                  if (action == 'delete') {
                                    await _cache.remove(item.url);
                                    setState(() {});
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // Action buttons
          if (_isInitialized && _cache.count > 0)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _showClearDialog(context);
                        },
                        icon: const Icon(Icons.delete_sweep, size: 18),
                        label: const Text('Xóa tất cả'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          _showMaxItemsDialog(context);
                        },
                        icon: const Icon(Icons.settings, size: 18),
                        label: const Text('Cài đặt'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showClearDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa bộ nhớ đệm?'),
        content: Text('Xóa tất cả ${_cache.count} mục đã lưu trong bộ nhớ đệm?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () async {
              await _cache.clear();
              Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  void _showMaxItemsDialog(BuildContext context) {
    final controller = TextEditingController(text: '${_cache.maxItems}');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Số mục tối đa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Số chương lưu tối đa',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Chương cũ hơn sẽ bị xóa tự động',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              final max = int.tryParse(controller.text) ?? 100;
              _cache.setMaxItems(max);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Đã đặt tối đa $max mục')),
              );
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  String _formatAge(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'vừa xong';
    if (diff.inHours < 1) return '${diff.inMinutes} phút trước';
    if (diff.inDays < 1) return '${diff.inHours} giờ trước';
    if (diff.inDays < 30) return '${diff.inDays} ngày trước';
    return '${(diff.inDays / 30).floor()} tháng trước';
  }
}
