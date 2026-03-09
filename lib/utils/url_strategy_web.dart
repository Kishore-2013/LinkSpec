import 'package:flutter_web_plugins/url_strategy.dart';

/// Web implementation — delegates to Flutter's built-in path URL strategy.
/// This removes the '#' from web URLs so deep links work cleanly.
void setPathUrlStrategy() => usePathUrlStrategy();
