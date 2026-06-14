import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static const String _keyLastFile = 'last_read_filename';
  static const String _keyLastPage = 'last_read_page_index';

  /// Commits current tracking vectors cleanly to the device configuration file.
  static Future<void> saveSession(String fileName, int pageIndex) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastFile, fileName);
    await prefs.setInt(_keyLastPage, pageIndex);
  }

  /// Retreives session state landmarks. Returns null if no active bookmark exists.
  static Future<Map<String, dynamic>?> getActiveSession() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? fileName = prefs.getString(_keyLastFile);
    final int? pageIndex = prefs.getInt(_keyLastPage);

    if (fileName == null || pageIndex == null) return null;

    return {'fileName': fileName, 'pageIndex': pageIndex};
  }

  static Future<void> clearSession() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLastFile);
    await prefs.remove(_keyLastPage);
  }
}
