/// Shared extensions for Iterable
/// Used by: ai_provider_manager, tts_backend_manager, web_novel_library

extension IterableExtensions<T> on Iterable<T> {
  /// Returns the first element or null if empty
  T? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}