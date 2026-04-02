import 'package:shared_preferences/shared_preferences.dart';

class AuthSession {
  static const String _loggedInKey = "is_logged_in";
  static const String _emailKey = "logged_in_email";
  static const String _usernameKey = "logged_in_username";
  static const String _pendingVerificationEmailKey = "pending_verification_email";

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_loggedInKey) ?? false;
  }

  static Future<void> setLoggedIn({
    required bool value,
    String? email,
    String? username,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_loggedInKey, value);
    if (email != null) {
      await prefs.setString(_emailKey, email);
    }
    if (username != null) {
      await prefs.setString(_usernameKey, username);
    }
    if (value) {
      await prefs.remove(_pendingVerificationEmailKey);
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_loggedInKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_pendingVerificationEmailKey);
  }

  static Future<String?> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_emailKey);
  }

  static Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_usernameKey);
  }

  static Future<void> setPendingVerificationEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingVerificationEmailKey, email);
  }

  static Future<String?> getPendingVerificationEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pendingVerificationEmailKey);
  }

  static Future<void> clearPendingVerificationEmail() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingVerificationEmailKey);
  }
}
