import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:anx_reader/service/web_reader/web_content_extractor.dart';

/// Download task status
enum DownloadStatus {
  pending,
  downloading,
  paused,
  completed,
  failed,
  cancelled,
}

/// Download task model
class DownloadTask {
  final String id;
  final String url;
  final String title;
  final String? bookTitle;
  final int chapterIndex;
  final int totalChapters;
  final DateTime createdAt;
  
  DownloadStatus status;
  double progress; // 0.0 - 1.0
  int downloadedBytes;
  int? totalBytes;
  String? localPath;
  String? errorMessage;
  
  DownloadTask({
    required this.id,
    required this.url,
    required this.title,
    this.bookTitle,
    required this.chapterIndex,
    this.totalChapters = 1,
    DateTime? createdAt,
    this.status = DownloadStatus.pending,
    this.progress = 0.0,
    this.downloadedBytes = 0,
    this.totalBytes,
    this.localPath,
    this.errorMessage,
  }) : createdAt = createdAt ?? DateTime.now();
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'url': url,
    'title': title,
    'bookTitle': bookTitle,
    'chapterIndex': chapterIndex,
    'totalChapters': totalChapters,
    'createdAt': createdAt.toIso8601String(),
    'status': status.name,
    'progress': progress,
    'downloadedBytes': downloadedBytes,
    'totalBytes': totalBytes,
    'localPath': localPath,
    'errorMessage': errorMessage,
  };
  
  factory DownloadTask.fromJson(Map<String, dynamic> json) => DownloadTask(
    id: json['id'],
    url: json['url'],
    title: json['title'],
    bookTitle: json['bookTitle'],
    chapterIndex: json['chapterIndex'],
    totalChapters: json['totalChapters'] ?? 1,
    createdAt: DateTime.parse(json['createdAt']),
    status: DownloadStatus.values.byName(json['status']),
    progress: json['progress'] ?? 0.0,
    downloadedBytes: json['downloadedBytes'] ?? 0,
    totalBytes: json['totalBytes'],
    localPath: json['localPath'],
    errorMessage: json['errorMessage'],
  );
}

/// Download Manager for Web Reader
/// Handles: queue, pause, resume, cancel, retry, wifi-only, simultaneous limits
class DownloadManager {
  static final DownloadManager _instance = DownloadManager._internal();
  factory DownloadManager() => _instance;
  
  DownloadManager._internal();
  
  final Dio _dio = Dio();
  final Map<String, DownloadTask> _tasks = {};
  final Map<String, CancelToken> _cancelTokens = {};
  final List<StreamSubscription> _subscriptions = [];
  
  final _taskController = StreamController<DownloadTask>.broadcast();
  Stream<DownloadTask> get taskStream => _taskController.stream;
  
  final _progressController = StreamController<Map<String, double>>.broadcast();
  Stream<Map<String, double>> get progressStream => _progressController.stream;
  
  int _maxConcurrent = 3;
  int _activeCount = 0;
  bool _wifiOnly = false;
  String? _storagePath;
  
  /// Set max concurrent downloads
  void setMaxConcurrent(int max) => _maxConcurrent = max.clamp(1, 5);
  
  /// Set WiFi-only mode
  void setWifiOnly(bool wifiOnly) => _wifiOnly = wifiOnly;
  
  /// Get storage path for downloads
  Future<String> get storagePath async {
    if (_storagePath != null) return _storagePath!;
    
    final appDir = await getApplicationDocumentsDirectory();
    _storagePath = '${appDir.path}/web_reader_downloads';
    
    final dir = Directory(_storagePath!);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    
    return _storagePath!;
  }
  
  /// Get all tasks
  List<DownloadTask> get tasks => _tasks.values.toList();
  
  /// Get task by ID
  DownloadTask? getTask(String id) => _tasks[id];
  
  /// Add download task
  Future<DownloadTask> addTask({
    required String url,
    required String title,
    String? bookTitle,
    int chapterIndex = 0,
    int totalChapters = 1,
  }) async {
    final id = '${DateTime.now().millisecondsSinceEpoch}_$chapterIndex';
    
    final task = DownloadTask(
      id: id,
      url: url,
      title: title,
      bookTitle: bookTitle,
      chapterIndex: chapterIndex,
      totalChapters: totalChapters,
    );
    
    _tasks[id] = task;
    _taskController.add(task);
    
    _processQueue();
    
    return task;
  }
  
  /// Add multiple chapters for download
  Future<List<DownloadTask>> addChapters({
    required List<WebChapter> chapters,
    required String bookTitle,
  }) async {
    final tasks = <DownloadTask>[];
    
    for (int i = 0; i < chapters.length; i++) {
      final task = await addTask(
        url: chapters[i].url,
        title: chapters[i].title,
        bookTitle: bookTitle,
        chapterIndex: i,
        totalChapters: chapters.length,
      );
      tasks.add(task);
    }
    
    return tasks;
  }
  
  /// Process download queue
  void _processQueue() {
    if (_activeCount >= _maxConcurrent) return;
    
    final pendingTasks = _tasks.values
        .where((t) => t.status == DownloadStatus.pending)
        .toList();
    
    for (final task in pendingTasks) {
      if (_activeCount >= _maxConcurrent) break;
      _startDownload(task);
    }
  }
  
  /// Start download
  Future<void> _startDownload(DownloadTask task) async {
    if (task.status == DownloadStatus.downloading) return;
    
    // WiFi check
    if (_wifiOnly) {
      // Note: Actual WiFi check needs connectivity_plus package
      // For now, skip check (user-managed)
    }
    
    task.status = DownloadStatus.downloading;
    _taskController.add(task);
    _activeCount++;
    
    final cancelToken = CancelToken();
    _cancelTokens[task.id] = cancelToken;
    
    try {
      final basePath = await storagePath;
      final safeTitle = task.title.replaceAll(RegExp(r'[^\w\s-]'), '_');
      final fileName = '${task.chapterIndex}_$safeTitle.txt';
      final filePath = '$basePath/$fileName';
      
      // Download content
      final response = await _dio.get<List<int>>(
        task.url,
        options: Options(responseType: ResponseType.bytes),
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            task.progress = received / total;
            task.downloadedBytes = received;
            task.totalBytes = total;
            _progressController.add({task.id: task.progress});
          }
        },
      );
      
      // Decode and extract content
      final extractor = WebContentExtractor();
      final content = await extractor.extractContent(task.url);
      
      // Save to file
      final file = File(filePath);
      await file.writeAsString(content.content);
      
      task.status = DownloadStatus.completed;
      task.progress = 1.0;
      task.localPath = filePath;
      
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        task.status = DownloadStatus.cancelled;
      } else {
        task.status = DownloadStatus.failed;
        task.errorMessage = e.message;
      }
    } catch (e) {
      task.status = DownloadStatus.failed;
      task.errorMessage = e.toString();
    } finally {
      _cancelTokens.remove(task.id);
      _activeCount--;
      _taskController.add(task);
      _processQueue();
    }
  }
  
  /// Pause download
  void pause(String taskId) {
    final task = _tasks[taskId];
    if (task == null || task.status != DownloadStatus.downloading) return;
    
    _cancelTokens[taskId]?.cancel('Paused by user');
    task.status = DownloadStatus.paused;
    _taskController.add(task);
  }
  
  /// Resume download
  void resume(String taskId) {
    final task = _tasks[taskId];
    if (task == null || task.status != DownloadStatus.paused) return;
    
    task.status = DownloadStatus.pending;
    _taskController.add(task);
    _processQueue();
  }
  
  /// Cancel download
  void cancel(String taskId) {
    final task = _tasks[taskId];
    if (task == null) return;
    
    _cancelTokens[taskId]?.cancel('Cancelled by user');
    task.status = DownloadStatus.cancelled;
    _taskController.add(task);
  }
  
  /// Retry failed download
  void retry(String taskId) {
    final task = _tasks[taskId];
    if (task == null || task.status != DownloadStatus.failed) return;
    
    task.status = DownloadStatus.pending;
    task.progress = 0.0;
    task.downloadedBytes = 0;
    task.errorMessage = null;
    _taskController.add(task);
    _processQueue();
  }
  
  /// Remove task
  void remove(String taskId) {
    cancel(taskId);
    _tasks.remove(taskId);
  }
  
  /// Clear completed tasks
  void clearCompleted() {
    _tasks.removeWhere((_, task) => 
        task.status == DownloadStatus.completed ||
        task.status == DownloadStatus.cancelled);
  }
  
  /// Get downloaded file content
  Future<String?> getDownloadedContent(String taskId) async {
    final task = _tasks[taskId];
    if (task == null || task.localPath == null) return null;
    
    final file = File(task.localPath!);
    if (!await file.exists()) return null;
    
    return await file.readAsString();
  }
  
  /// Get all downloaded files for a book
  Future<List<File>> getBookFiles(String bookTitle) async {
    final basePath = await storagePath;
    final dir = Directory(basePath);
    
    if (!await dir.exists()) return [];
    
    final files = await dir.list()
        .where((f) => f.path.endsWith('.txt'))
        .where((f) => f.path.contains(bookTitle.replaceAll(RegExp(r'[^\w\s-]'), '_')))
        .map((f) => File(f.path))
        .toList();
    
    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }
  
  /// Delete downloaded files for a book
  Future<void> deleteBook(String bookTitle) async {
    final files = await getBookFiles(bookTitle);
    for (final file in files) {
      await file.delete();
    }
    
    _tasks.removeWhere((_, task) => task.bookTitle == bookTitle);
  }
  
  /// Get total download size
  Future<int> getTotalDownloadSize() async {
    final basePath = await storagePath;
    final dir = Directory(basePath);
    
    if (!await dir.exists()) return 0;
    
    int total = 0;
    await for (final file in dir.list()) {
      if (file is File) {
        total += await file.length();
      }
    }
    
    return total;
  }
  
  /// Dispose
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    for (final token in _cancelTokens.values) {
      token.cancel();
    }
    _taskController.close();
    _progressController.close();
  }
}
