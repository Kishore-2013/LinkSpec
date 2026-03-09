import '../config/app_constants.dart';

/// Post content sanitizer — platform-agnostic, no Edge Functions needed.
///
/// All sanitization happens client-side before the content reaches Supabase.
class PostSanitizer {
  PostSanitizer._();

  static const int maxLength = AppConstants.maxPostLength;
  static const int minLength = AppConstants.minPostLength;

  // ── Public API ────────────────────────────────────────────────

  /// Full pipeline: trim → collapse whitespace → validate.
  /// Returns a [SanitizeResult] with the cleaned content and any error.
  static SanitizeResult processPostContent(String input) {
    // Step 1: Trim leading/trailing whitespace
    String text = input.trim();

    // Step 2: Collapse 5+ consecutive spaces into one
    text = text.replaceAll(RegExp(r' {5,}'), ' ');

    // Step 3: Collapse 5+ consecutive newlines into two (preserve paragraph spacing)
    text = text.replaceAll(RegExp(r'\n{5,}'), '\n\n');

    // Step 4: Collapse runs of 3+ blank lines between hashtag rows into one blank line
    // e.g.  "#tag1\n\n\n\n#tag2" → "#tag1\n\n#tag2"
    text = text.replaceAll(RegExp(r'(#\w+)\n{3,}(?=#)'), r'$1\n\n');

    // Step 5: Validate
    final error = _validate(text);

    return SanitizeResult(
      cleaned: text,
      error: error,
      isValid: error == null,
    );
  }

  /// Standalone validity check (used by UI for real-time feedback).
  static bool isValidPost(String raw) => _validate(raw.trim()) == null;

  // ── Private helpers ───────────────────────────────────────────

  static String? _validate(String text) {
    if (text.isEmpty) {
      return 'Please enter a valid post with meaningful content.';
    }

    // Must contain at least one letter or digit
    if (!text.contains(RegExp(r'[a-zA-Z0-9]'))) {
      return 'Please enter a valid post with meaningful content.';
    }

    if (text.length < minLength) {
      final remaining = minLength - text.length;
      return 'Post is too short. Add at least $remaining more character${remaining == 1 ? '' : 's'} (minimum $minLength).';
    }

    if (text.length > maxLength) {
      return 'Post exceeds the ${maxLength}-character limit.';
    }

    return null; // valid
  }
}

/// Result object returned by [PostSanitizer.processPostContent].
class SanitizeResult {
  final String cleaned;
  final String? error;
  final bool isValid;

  const SanitizeResult({
    required this.cleaned,
    required this.error,
    required this.isValid,
  });
}
