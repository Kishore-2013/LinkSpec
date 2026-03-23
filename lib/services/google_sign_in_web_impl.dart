// ignore_for_file: avoid_web_libraries_in_flutter
// Web-only implementation — compiled only when dart.library.js_interop is present.
import '../utils/google_gis_interop.dart' as gis;

void disableGoogleAutoSelectPlatform() {
  gis.disableGoogleAutoSelect();
}
