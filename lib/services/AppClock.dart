import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitute/services/SchoolStorage.dart';

class AppClock {
  static DateTime? _overriddenNow;

  static Future<void> setOverriddenNow(DateTime? date) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (date == null) {
      await prefs.remove(SchoolStorage.scopedKey(prefs, 'overriddenNow'));
    } else {
      await prefs.setString(
        SchoolStorage.scopedKey(prefs, 'overriddenNow'),
        date.toIso8601String(),
      );
    }
    _overriddenNow = date;
  }

  static Future<DateTime?> getOverriddenNow() async {
    if (_overriddenNow != null) return _overriddenNow;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(SchoolStorage.scopedKey(prefs, 'overriddenNow'));
    if (stored == null) return null;
    _overriddenNow = DateTime.tryParse(stored);
    return _overriddenNow;
  }

  static DateTime now() {
    return _overriddenNow ?? DateTime.now();
  }
}
