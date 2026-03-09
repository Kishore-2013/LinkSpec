import 'dart:collection';
import 'package:flutter/foundation.dart';

/// PerformanceUtils: Memoization and UI optimization helpers.
class PerformanceUtils {
  static final Map<String, dynamic> _memoCache = HashMap();

  /// memoize: Caches the result of an expensive computation.
  /// 
  /// Usage: 
  /// final result = PerformanceUtils.memoize('engagement_${post.id}', () => calculate(post));
  static T memoize<T>(String key, T Function() computation) {
    if (_memoCache.containsKey(key)) {
      return _memoCache[key] as T;
    }
    final result = computation();
    _memoCache[key] = result;
    return result;
  }

  /// invalidate: Clears specific memoized result.
  static void invalidate(String key) => _memoCache.remove(key);

  /// calculatePostEngagement: Memoized expensive calculation for post metrics.
  static double calculatePostEngagement(int likeCount, int commentCount) {
    final key = 'engagement_math_$likeCount-$commentCount';
    return memoize(key, () {
      // Simulate expensive weight calculation
      if (likeCount == 0 && commentCount == 0) return 0.0;
      return (likeCount * 0.4) + (commentCount * 0.6);
    });
  }

  /// formatMedicalDate: Memoized date formatting for the medical domain.
  static String formatMedicalDate(DateTime date) {
    final key = 'date_${date.millisecondsSinceEpoch}';
    return memoize(key, () {
      // Expensive Locale/Date parsing
      return '${date.day}/${date.month}/${date.year}';
    });
  }
}
