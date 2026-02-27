import 'package:shared_preferences/shared_preferences.dart';

class SessionData {
  final String role;
  final String? category;

  const SessionData({
    required this.role,
    this.category,
  });
}

class SessionService {
  static const _kRole = 'app_role';
  static const _kCategory = 'app_category';

  static Future<void> saveAdminSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRole, 'admin');
    await prefs.remove(_kCategory);
  }

  static Future<void> saveUserSession(String category) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRole, 'user');
    await prefs.setString(_kCategory, category);
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRole);
    await prefs.remove(_kCategory);
  }

  static Future<SessionData?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString(_kRole);
    if (role == null || role.isEmpty) return null;
    final category = prefs.getString(_kCategory);
    return SessionData(role: role, category: category);
  }
}

