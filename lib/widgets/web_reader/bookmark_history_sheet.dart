import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:anx_reader/service/web_reader/bookmark_service.dart';

/// Bookmark & History Sheet
/// Shows bookmarks + reading history with sharing
class BookmarkHistorySheet extends StatefulWidget {
  final String? currentUrl;
  final String? currentTitle;
  final String? currentChapterTitle;
  final int currentChapterIndex;
  final double currentScrollPosition;
  final ValueChanged<String>? onNavigate; // URL to navigate to

  const BookmarkHistorySheet({
    super.key,
    this.currentUrl,
    this.currentTitle,
    this.currentChapterTitle,
    this.currentChapterIndex = 0,
    this.currentScrollPosition = 0.0,
    this.onNavigate,
  });

  static Future<void> show(
    BuildContext context, {
    String? currentUrl,
    String? currentTitle,
    String? currentChapterTitle,
    int currentChapterIndex = 0,
    double currentScrollPosition = 0.0,
    ValueChanged<String>? onNavigate,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BookmarkHistorySheet(
        currentUrl: currentUrl,
        currentTitle: currentTitle,
        currentChapterTitle: currentChapterTitle,
        currentChapterIndex: currentChapterIndex,
        currentScrollPosition: currentScrollPosition,
        onNavigate: onNavigate,
      ),
    );
  }

  @override
  State<BookmarkHistorySheet> createState() => _BookmarkHistorySheetState();
}

class _BookmarkHistorySheetState extends State<BookmarkHistorySheet>
    with SingleTickerProviderStateMixin {
  final BookmarkService _bookmarkService = BookmarkService();
  late TabController _tabController;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _init();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _bookmarkService.init();
    setState(() => _isInitialized = true);
  }

  @override
  Widget build(BuildContext context) {
    final isCurrentBookmarked = widget.currentUrl != null &&
        _bookmarkService.isBookmarked(widget.currentUrl!);

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
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

          // Title + bookmark toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.bookmark_border, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Đánh dấu & Lịch sử',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (widget.currentUrl != null)
                  IconButton(
                    icon: Icon(
                      isCurrentBookmarked ? Icons.bookmark : Icons.bookmark_border,
                      color: isCurrentBookmarked ? Colors.amber : Colors.grey,
                    ),
                    onPressed: () async {
                      if (isCurrentBookmarked) {
                        await _bookmarkService.removeBookmark(widget.currentUrl!);
                      } else {
                        await _bookmarkService.saveBookmark(
                          url: widget.currentUrl!,
                          title: widget.currentTitle ?? '',
                          chapterTitle: widget.currentChapterTitle ?? '',
                          scrollPosition: widget.currentScrollPosition,
                          chapterIndex: widget.currentChapterIndex,
                        );
                      }
                      setState(() {});
                    },
                  ),
                if (widget.currentUrl != null)
                  IconButton(
                    icon: const Icon(Icons.share, size: 20),
                    onPressed: () {
                      Share.share(
                        '${widget.currentTitle ?? "Truyện"}\n${widget.currentChapterTitle ?? ""}\n${widget.currentUrl ?? ""}',
                      );
                    },
                  ),
              ],
            ),
          ),

          // Tab bar
          TabBar(
            controller: _tabController,
            tabs: [
              Tab(
                child: Text(
                  'Đánh dấu (${_bookmarkService.bookmarkCount})',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              Tab(
                child: Text(
                  'Lịch sử (${_bookmarkService.historyCount})',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),

          // Content
          Expanded(
            child: !_isInitialized
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildBookmarksTab(),
                      _buildHistoryTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookmarksTab() {
    final bookmarks = _bookmarkService.allBookmarks;
    if (bookmarks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_border, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'Chưa có đánh dấu nào',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Nhấn icon bookmark để lưu vị trí đọc',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: bookmarks.length,
      itemBuilder: (context, index) {
        final bm = bookmarks[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 6),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.amber.shade50,
              child: const Icon(Icons.bookmark, color: Colors.amber, size: 18),
            ),
            title: Text(
              bm.title.isNotEmpty ? bm.title : bm.url,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
            subtitle: Text(
              '${bm.chapterTitle.isNotEmpty ? bm.chapterTitle : "Chương ${bm.chapterIndex + 1}"}\n${_formatDate(bm.updatedAt)}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            isThreeLine: true,
            trailing: PopupMenuButton<String>(
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'open', child: Text('Mở')),
                const PopupMenuItem(value: 'delete', child: Text('Xóa')),
              ],
              onSelected: (action) {
                if (action == 'open') {
                  widget.onNavigate?.call(bm.url);
                  Navigator.pop(context);
                } else if (action == 'delete') {
                  _bookmarkService.removeBookmark(bm.url);
                  setState(() {});
                }
              },
            ),
            onTap: () {
              widget.onNavigate?.call(bm.url);
              Navigator.pop(context);
            },
          ),
        );
      },
    );
  }

  Widget _buildHistoryTab() {
    final history = _bookmarkService.allHistory;
    if (history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'Chưa có lịch sử đọc',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: history.length + 1, // +1 for clear button
      itemBuilder: (context, index) {
        if (index == history.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: TextButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Xóa lịch sử?'),
                      content: Text('Xóa tất cả ${history.length} mục lịch sử?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Hủy'),
                        ),
                        FilledButton(
                          onPressed: () {
                            _bookmarkService.clearHistory();
                            Navigator.pop(ctx);
                            setState(() {});
                          },
                          child: const Text('Xóa'),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.delete_sweep, size: 18),
                label: const Text('Xóa lịch sử'),
              ),
            ),
          );
        }

        final hs = history[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 6),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: hs.completed ? Colors.green.shade50 : Colors.blue.shade50,
              child: Icon(
                hs.completed ? Icons.check_circle : Icons.history,
                color: hs.completed ? Colors.green : Colors.blue,
                size: 18,
              ),
            ),
            title: Text(
              hs.title.isNotEmpty ? hs.title : hs.url,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
            subtitle: Text(
              '${hs.chapterTitle.isNotEmpty ? hs.chapterTitle : ""}\n${_formatDate(hs.readAt)}${hs.completed ? " · Đã hoàn thành" : ""}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            isThreeLine: true,
            onTap: () {
              widget.onNavigate?.call(hs.url);
              Navigator.pop(context);
            },
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'vừa xong';
    if (diff.inHours < 1) return '${diff.inMinutes} phút trước';
    if (diff.inDays < 1) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return '${date.day}/${date.month}/${date.year}';
  }
}
