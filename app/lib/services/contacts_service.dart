import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_contact.dart';

class ContactsService {
  static const _key = 'app_contacts';

  Future<List<AppContact>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw.map((s) => AppContact.fromJson(jsonDecode(s))).toList();
  }

  Future<void> add(AppContact contact) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    raw.add(jsonEncode(contact.toJson()));
    await prefs.setStringList(_key, raw);
  }

  Future<void> delete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    raw.removeWhere((s) {
      final m = jsonDecode(s) as Map<String, dynamic>;
      return m['id'] == id;
    });
    await prefs.setStringList(_key, raw);
  }
}
